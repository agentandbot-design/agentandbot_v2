"""
Google Docs → mem.agentandbot.com connector

Senkronize ettigi seyler:
- Google Docs (text content)
- Google Drive folders (doc listesi)

Auth: GOOGLE_CREDENTIALS_FILE (service account JSON) veya GOOGLE_OAUTH_TOKEN_FILE.
"""

import os
import argparse
from datetime import datetime
from typing import List, Dict, Any

from mem_client import MemClient, StateStore


class GoogleDocsConnector:
    def __init__(self, mem: MemClient = None, credentials_file: str = ""):
        self.mem = mem or MemClient()
        self.credentials_file = credentials_file or os.getenv("GOOGLE_CREDENTIALS_FILE", "")
        self.state = StateStore("state/google_docs.json")
        self._service = None

    def _get_service(self):
        if self._service:
            return self._service

        if not self.credentials_file:
            raise ValueError("GOOGLE_CREDENTIALS_FILE env must be set")

        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        SCOPES = [
            "https://www.googleapis.com/auth/documents.readonly",
            "https://www.googleapis.com/auth/drive.readonly",
        ]

        creds = service_account.Credentials.from_service_account_file(
            self.credentials_file, scopes=SCOPES
        )

        self._service = {
            "docs": build("docs", "v1", credentials=creds),
            "drive": build("drive", "v3", credentials=creds),
        }
        return self._service

    def sync_folder(self, folder_id: str, max_docs: int = 50) -> int:
        """Belirli bir Drive klasorundeki tum Google Docs'lari ingeste et."""
        service = self._get_service()
        drive = service["drive"]

        # Klasordeki tum Google Docs'lari listele
        query = f"'{folder_id}' in parents and mimeType='application/vnd.google-apps.document' and trashed=false"
        results = drive.files().list(
            q=query,
            fields="files(id, name, modifiedTime, owners(emailAddress))",
            pageSize=min(max_docs, 100),
            orderBy="modifiedTime desc",
        ).execute()

        files = results.get("files", [])
        count = 0

        for f in files:
            doc_id = f["id"]
            last_synced = self.state.get(f"synced_{doc_id}")
            modified = f["modifiedTime"]

            # Degismediyse atla
            if last_synced and last_synced >= modified:
                continue

            # Doc icerigini cek
            doc = service["docs"].documents().get(documentId=doc_id).execute()
            text = self._extract_text(doc)

            if not text.strip():
                continue

            self.mem.ingest(
                {
                    "content": self.mem.normalize(text),
                    "source": "gdocs",
                    "project": "google-docs",
                    "title": f["name"],
                    "metadata": {
                        "type": "google_doc",
                        "doc_id": doc_id,
                        "folder_id": folder_id,
                        "modified": modified,
                        "owners": [o["emailAddress"] for o in f.get("owners", [])],
                        "url": f"https://docs.google.com/document/d/{doc_id}/edit",
                    },
                }
            )

            self.state.set(f"synced_{doc_id}", modified)
            count += 1

        return count

    def _extract_text(self, doc: Dict[str, Any]) -> str:
        """Google Docs API response'tan text cikart."""
        content = doc.get("body", {}).get("content", [])
        texts = []

        for elem in content:
            if "paragraph" in elem:
                for pc in elem["paragraph"].get("elements", []):
                    if "textRun" in pc:
                        texts.append(pc["textRun"].get("content", ""))

        return "\n".join(texts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--folder-id", required=True, help="Google Drive folder ID")
    ap.add_argument("--max-docs", type=int, default=50)
    args = ap.parse_args()

    conn = GoogleDocsConnector()
    n = conn.sync_folder(args.folder_id, args.max_docs)
    print(f"docs: {n} ingested")


if __name__ == "__main__":
    main()
