#!/usr/bin/env python3
"""folder_connector.py — lokal klasördeki metin dosyalarını mem'e indeksler.

Desteklenen: .md .txt .json .csv .log .yaml .yml .ex .py (metin olarak)
Büyük dosyalar 8KB chunk'lara bölünür.

Kullanim:
  python3 folder_connector.py --path /data/stacks --project runbook
  python3 folder_connector.py --path ~/notes --project notes --dry-run
"""
import argparse
import hashlib
import json
import os
import sys
import urllib.request

MEM_URL = os.environ.get("MEM_URL", "https://mem.agentandbot.com")
MEM_TOKEN = os.environ.get("MEM_TOKEN", "")
STATE_DIR = os.path.join(os.path.dirname(__file__), "state")

EXTS = {".md", ".txt", ".json", ".csv", ".log", ".yaml", ".yml", ".ex", ".exs", ".py", ".sh", ".ts", ".js"}
SKIP_DIRS = {"node_modules", ".git", "_build", "deps", ".venv", "venv", "__pycache__", "dist", "build"}
CHUNK = 8000
MAX_FILE = 512 * 1024  # 512KB üstü atlanır


def state_path(folder: str, project: str) -> str:
    key = hashlib.sha256(f"{folder}:{project}".encode()).hexdigest()[:16]
    return os.path.join(STATE_DIR, f"folder_{key}.json")


def mem_ingest(content, title, project, source="doc"):
    body = json.dumps({"content": content, "title": title, "source": source, "project": project}).encode()
    req = urllib.request.Request(
        f"{MEM_URL}/api/memory", data=body,
        headers={"Authorization": f"Bearer {MEM_TOKEN}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def iter_files(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in sorted(filenames):
            ext = os.path.splitext(fn)[1].lower()
            if ext in EXTS:
                yield os.path.join(dirpath, fn)


def sync(path: str, project: str, dry_run=False):
    if not MEM_TOKEN:
        print("MEM_TOKEN gerekli"); sys.exit(1)
    if not os.path.isdir(path):
        print(f"Klasör yok: {path}"); sys.exit(1)

    sp = state_path(path, project)
    state = json.load(open(sp)) if os.path.exists(sp) else {"files": {}}

    files = list(iter_files(path))
    new_count, skip_count, err_count = 0, 0, 0

    for fp in files:
        try:
            st = os.stat(fp)
        except OSError:
            continue
        rel = os.path.relpath(fp, path)
        key = rel
        prev = state["files"].get(key)

        if prev and prev["size"] == st.st_size and prev["mtime"] == int(st.st_mtime):
            skip_count += 1
            continue

        if st.st_size > MAX_FILE:
            skip_count += 1
            continue

        try:
            text = open(fp, encoding="utf-8", errors="ignore").read()
        except OSError:
            err_count += 1
            continue

        # chunk'la
        parts = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)] or [""]
        for idx, part in enumerate(parts, 1):
            title = rel if len(parts) == 1 else f"{rel} ({idx}/{len(parts)})"
            if dry_run:
                print(f"[dry] {title} — {len(part)} char")
            else:
                try:
                    mem_ingest(part, title, project)
                except Exception as e:
                    err_count += 1
                    print(f"  hata {title}: {e}")
                    continue

        new_count += 1
        state["files"][key] = {"size": st.st_size, "mtime": int(st.st_mtime)}

    if not dry_run:
        os.makedirs(STATE_DIR, exist_ok=True)
        json.dump(state, open(sp, "w"), indent=2)

    print(f"\nKlasör sync: {new_count} yeni dosya, {skip_count} atlandı, {err_count} hata "
          f"(kaynak: {path}, proje: {project})")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--path", required=True)
    p.add_argument("--project", default="docs")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    sync(a.path, a.project, a.dry_run)
