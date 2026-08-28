"""
Chat log → mem.agentandbot.com connector

Hermes/AAB chat loglarini mem'e yazar. Kaynak formatlari:
- JSONL (her satir bir mesaj: {"ts": ..., "user": ..., "text": ...})
- Duz metin loglari ("[2026-08-27 12:00] user: text")
- Hermes session DB export'u

Ayrica canli mod: --watch ile yeni satirlari takip eder.
"""

import os
import json
import argparse
import time
from datetime import datetime
from typing import List, Dict, Any

from mem_client import MemClient, StateStore


class ChatConnector:
    def __init__(self, mem: MemClient = None, project: str = "chat"):
        self.mem = mem or MemClient()
        self.project = project
        self.state = StateStore(f"state/chat_{project}.json")

    def sync_jsonl(self, path: str, max_messages: int = 500) -> int:
        """JSONL dosyasini oku, mesajlari burst/thread halinde ingeste et."""
        last_offset = self.state.get(f"offset_{path}", 0)

        messages = []
        with open(path) as f:
            f.seek(last_offset)
            for i, line in enumerate(f):
                if i >= max_messages:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                    messages.append(msg)
                except json.JSONDecodeError:
                    continue

        if not messages:
            return 0

        # Burst'leri olustur: ayni kullanici, 5dk arayla
        bursts = self._group_into_bursts(messages)

        count = 0
        for burst in bursts:
            text_parts = []
            for m in burst:
                ts = m.get("ts") or m.get("timestamp") or ""
                user = m.get("user") or m.get("role") or "unknown"
                text = m.get("text") or m.get("content") or m.get("message") or ""
                text_parts.append(f"[{ts}] <{user}>: {text}")

            content = "\n".join(text_parts)
            if not content.strip():
                continue

            self.mem.ingest(
                {
                    "source": "chat",
                    "project": self.project,
                    "content": self.mem.normalize(content),
                    "title": f"Chat burst ({len(burst)} messages)",
                    "metadata": {
                        "type": "burst",
                        "message_count": len(burst),
                        "participants": list(set(
                            m.get("user") or m.get("role") or "unknown" for m in burst
                        )),
                        "log_file": path,
                    },
                }
            )
            count += 1

        # Offset'i guncelle
        new_offset = f.tell() if hasattr(f, "tell") else last_offset
        self.state.set(f"offset_{path}", new_offset)

        return count

    def sync_directory(self, dir_path: str, pattern: str = "*.jsonl", max_files: int = 10) -> int:
        """Klasordeki tum JSONL dosyalarini senkronize et."""
        import glob

        files = sorted(glob.glob(os.path.join(dir_path, pattern)))[:max_files]
        total = 0
        for f in files:
            n = self.sync_jsonl(f)
            print(f"  {os.path.basename(f)}: {n} chunks")
            total += n
        return total

    def _group_into_bursts(self, messages: List[Dict], gap_seconds: int = 300) -> List[List[Dict]]:
        if not messages:
            return []

        def ts_of(m):
            v = m.get("ts") or m.get("timestamp")
            if isinstance(v, (int, float)):
                return float(v)
            if isinstance(v, str):
                try:
                    return datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()
                except ValueError:
                    return 0.0
            return 0.0

        bursts = []
        current = [messages[0]]

        for msg in messages[1:]:
            prev = current[-1]
            same_user = (msg.get("user") or msg.get("role")) == (prev.get("user") or prev.get("role"))
            time_gap = ts_of(msg) - ts_of(prev)

            if same_user and time_gap < gap_seconds:
                current.append(msg)
            else:
                bursts.append(current)
                current = [msg]

        bursts.append(current)
        return bursts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="Tek JSONL dosyasi")
    ap.add_argument("--dir", help="JSONL klasoru")
    ap.add_argument("--project", default="chat")
    args = ap.parse_args()

    conn = ChatConnector(project=args.project)

    if args.file:
        n = conn.sync_jsonl(args.file)
        print(f"{args.file}: {n} chunks")
    elif args.dir:
        total = conn.sync_directory(args.dir)
        print(f"total: {total} chunks")
    else:
        ap.error("--file veya --dir gerekli")


if __name__ == "__main__":
    main()
