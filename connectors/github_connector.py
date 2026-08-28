"""
GitHub → mem.agentandbot.com connector

Senkronize ettigi seyler:
- Issues (body + comments)
- Pull Requests (body + review comments)
- Commit messages (opsiyonel, --with-commits)
- README / docs klasoru (opsiyonel, --with-docs)

Auth: GITHUB_TOKEN (PAT) veya gh CLI'nin mevcut auth'u.
"""

import os
import argparse
from datetime import datetime

import requests

from mem_client import MemClient, StateStore


class GitHubConnector:
    API = "https://api.github.com"

    def __init__(self, repo: str, token: str = "", mem: MemClient = None):
        self.repo = repo
        self.token = token or os.getenv("GITHUB_TOKEN") or self._gh_cli_token()
        self.mem = mem or MemClient()
        self.s = requests.Session()
        if self.token:
            self.s.headers["Authorization"] = f"Bearer {self.token}"
        self.s.headers["Accept"] = "application/vnd.github+json"
        self.state = StateStore(f"state/github_{repo.replace('/', '_')}.json")

    @staticmethod
    def _gh_cli_token() -> str:
        """gh CLI token'ini oku (auth status --show-token yoksa bos doner)."""
        import subprocess

        try:
            out = subprocess.run(
                ["gh", "auth", "token"], capture_output=True, text=True, timeout=10
            )
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
        return ""

    # -----------------------------------------------------------------
    # Sync
    # -----------------------------------------------------------------
    def sync_issues(self, limit: int = 100) -> int:
        since = self.state.get("issues_since")
        params = {"state": "all", "per_page": min(limit, 100), "sort": "updated", "direction": "desc"}
        if since:
            params["since"] = since

        issues = self._paginated(f"/repos/{self.repo}/issues", params)
        count = 0
        for iss in issues[:limit]:
            if "pull_request" in iss:
                continue
            body = iss.get("body") or ""
            if not body.strip():
                continue
            self.mem.ingest(
                {
                    "content": self.mem.normalize(
                        f"[{iss['title']}]\n\n{body}\n\n(state: {iss['state']})"
                    ),
                    "source": "github",
                    "project": self.repo.split("/")[-1],
                    "title": f"Issue #{iss['number']}: {iss['title']}",
                    "metadata": {
                        "type": "issue",
                        "number": iss["number"],
                        "author": iss["user"]["login"],
                        "state": iss["state"],
                        "url": iss["html_url"],
                        "labels": [l["name"] for l in iss.get("labels", [])],
                    },
                }
            )
            self._sync_issue_comments(iss["number"])
            count += 1

        if issues:
            latest = max(i["updated_at"] for i in issues)
            self.state.set("issues_since", latest)
        return count

    def _sync_issue_comments(self, number: int):
        comments = self._paginated(f"/repos/{self.repo}/issues/{number}/comments", {})
        for c in comments:
            if not (c.get("body") or "").strip():
                continue
            self.mem.ingest(
                {
                    "content": self.mem.normalize(c["body"]),
                    "source": "github",
                    "project": self.repo.split("/")[-1],
                    "title": f"Comment on issue #{number}",
                    "metadata": {
                        "type": "issue_comment",
                        "number": number,
                        "author": c["user"]["login"],
                        "url": c["html_url"],
                    },
                }
            )

    def sync_prs(self, limit: int = 50) -> int:
        prs = self._paginated(
            f"/repos/{self.repo}/pulls",
            {"state": "all", "per_page": min(limit, 100), "sort": "updated", "direction": "desc"},
        )
        count = 0
        for pr in prs[:limit]:
            body = pr.get("body") or ""
            if not body.strip():
                continue
            self.mem.ingest(
                {
                    "content": self.mem.normalize(
                        f"[PR #{pr['number']}: {pr['title']}]\n\n{body}"
                    ),
                    "source": "github",
                    "project": self.repo.split("/")[-1],
                    "title": f"PR #{pr['number']}: {pr['title']}",
                    "metadata": {
                        "type": "pull_request",
                        "number": pr["number"],
                        "author": pr["user"]["login"],
                        "merged": bool(pr.get("merged_at")),
                        "url": pr["html_url"],
                    },
                }
            )
            count += 1
        return count

    def sync_docs(self, docs_dir: str = "docs") -> int:
        """docs/ klasorundeki .md dosyalarini ingeste et."""
        contents = self._get(f"/repos/{self.repo}/contents/{docs_dir}")
        if not isinstance(contents, list):
            return 0
        count = 0
        for item in contents:
            if item["type"] != "file" or not item["name"].endswith(".md"):
                continue
            file_resp = self._get(item["url"])
            if not file_resp or file_resp.get("encoding") != "base64":
                continue
            import base64

            text = base64.b64decode(file_resp["content"]).decode("utf-8", errors="replace")
            self.mem.ingest(
                {
                    "content": self.mem.normalize(text),
                    "source": "github",
                    "project": self.repo.split("/")[-1],
                    "title": item["name"],
                    "metadata": {
                        "type": "doc",
                        "path": item["path"],
                        "url": item["html_url"],
                    },
                }
            )
            count += 1
        return count

    # -----------------------------------------------------------------
    def _paginated(self, path: str, params: dict, max_pages: int = 5) -> list:
        items = []
        for page in range(1, max_pages + 1):
            p = dict(params, page=page)
            batch = self._get(path, p)
            if not isinstance(batch, list):
                break
            items.extend(batch)
            if len(batch) < p.get("per_page", 30):
                break
        return items

    def _get(self, path: str, params: dict = None):
        url = path if path.startswith("http") else self.API + path
        r = self.s.get(url, params=params or {}, timeout=30)
        if r.status_code == 403 and "rate limit" in r.text.lower():
            raise RuntimeError("GitHub rate limit — GITHUB_TOKEN gerekli")
        if r.status_code != 200:
            return None
        return r.json()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="owner/repo")
    ap.add_argument("--issues", action="store_true")
    ap.add_argument("--prs", action="store_true")
    ap.add_argument("--docs", action="store_true")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    conn = GitHubConnector(repo=args.repo)

    if args.all or args.issues:
        n = conn.sync_issues()
        print(f"issues: {n} ingested")
    if args.all or args.prs:
        n = conn.sync_prs()
        print(f"prs: {n} ingested")
    if args.all or args.docs:
        n = conn.sync_docs()
        print(f"docs: {n} ingested")


if __name__ == "__main__":
    main()
