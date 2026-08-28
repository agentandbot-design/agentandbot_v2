"""
Slack → mem.agentandbot.com connector

Senkronize ettigi seyler:
- Channel messages (tek tek veya burst halinde)
- Thread replies (parent message + tum replies tek chunk)
- Files (opsiyonel)

Auth: SLACK_BOT_TOKEN (xoxb-...)
Bot'un ilgili kanallarda "channels:history" ve "channels:read" scope'lari olmali.
"""

import os
import argparse
import time
from datetime import datetime
from typing import List, Dict, Any

import requests

from mem_client import MemClient, StateStore


class SlackConnector:
    API = "https://slack.com/api"

    def __init__(self, token: str = "", mem: MemClient = None):
        self.token = token or os.getenv("SLACK_BOT_TOKEN", "")
        if not self.token:
            raise ValueError("SLACK_BOT_TOKEN env must be set")
        self.mem = mem or MemClient()
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"Bearer {self.token}"
        self.state = StateStore("state/slack.json")

    def sync_channel(self, channel_id: str, limit: int = 200) -> int:
        """Tek bir Slack kanalini senkronize et.
        Thread'ler parent + replies olarak tek chunk'ta gider.
        """
        since_ts = self.state.get(f"channel_{channel_id}_ts", "0")
        messages = self._fetch_history(channel_id, oldest=since_ts, limit=limit)

        if not messages:
            return 0

        # Thread'leri grupla
        threads: Dict[str, List[Dict]] = {}
        standalone = []

        for msg in messages:
            if msg.get("subtype") in ("channel_join", "channel_leave", "bot_message"):
                continue
            thread_ts = msg.get("thread_ts")
            if thread_ts and thread_ts != msg["ts"]:
                # Reply — parent'a ekle
                threads.setdefault(thread_ts, []).append(msg)
            elif msg.get("reply_count", 0) > 0:
                # Parent — replies'leri cek
                replies = self._fetch_replies(channel_id, msg["ts"])
                threads[msg["ts"]] = [msg] + replies
            else:
                standalone.append(msg)

        count = 0

        # Thread'leri chunk olarak gonder
        for thread_ts, msgs in threads.items():
            parent = msgs[0]
            text_parts = []
            for m in msgs:
                user = m.get("user", "bot")
                ts = datetime.fromtimestamp(float(m["ts"])).strftime("%Y-%m-%d %H:%M")
                text_parts.append(f"[{ts}] <{user}>: {m.get('text', '')}")

            content = "\n".join(text_parts)
            if not content.strip():
                continue

            self.mem.ingest(
                {
                    "content": self.mem.normalize(content),
                    "source": "slack",
                    "project": channel_id,
                    "title": f"Thread in #{channel_id}",
                    "metadata": {
                        "type": "thread",
                        "channel_id": channel_id,
                        "thread_ts": thread_ts,
                        "message_count": len(msgs),
                        "participants": list(set(m.get("user", "") for m in msgs)),
                    },
                }
            )
            count += 1

        # Standalone mesajlari burst halinde gonder (ayni yazar, 5dk icinde)
        bursts = self._group_into_bursts(standalone)
        for burst in bursts:
            text_parts = []
            for m in burst:
                user = m.get("user", "bot")
                ts = datetime.fromtimestamp(float(m["ts"])).strftime("%Y-%m-%d %H:%M")
                text_parts.append(f"[{ts}] <{user}>: {m.get('text', '')}")

            content = "\n".join(text_parts)
            if not content.strip():
                continue

            self.mem.ingest(
                {
                    "content": self.mem.normalize(content),
                    "source": "slack",
                    "project": channel_id,
                    "title": f"Messages in #{channel_id}",
                    "metadata": {
                        "type": "burst",
                        "channel_id": channel_id,
                        "message_count": len(burst),
                        "authors": list(set(m.get("user", "") for m in burst)),
                    },
                }
            )
            count += 1

        # Son timestamp'i kaydet
        latest_ts = max(float(m["ts"]) for m in messages)
        self.state.set(f"channel_{channel_id}_ts", str(latest_ts))

        return count

    def list_channels(self) -> List[Dict[str, Any]]:
        """Bot'un erisebildigi kanallari listele."""
        resp = self.s.get(
            f"{self.API}/conversations.list",
            params={"types": "public_channel,private_channel", "limit": 200},
            timeout=30,
        )
        data = resp.json()
        if not data.get("ok"):
            return []
        return data.get("channels", [])

    def _fetch_history(self, channel_id: str, oldest: str = "0", limit: int = 200) -> List[Dict]:
        messages = []
        cursor = None

        while len(messages) < limit:
            params = {
                "channel": channel_id,
                "oldest": oldest,
                "limit": min(limit - len(messages), 200),
            }
            if cursor:
                params["cursor"] = cursor

            resp = self.s.get(f"{self.API}/conversations.history", params=params, timeout=30)
            data = resp.json()

            if not data.get("ok"):
                break

            messages.extend(data.get("messages", []))
            cursor = data.get("response_metadata", {}).get("next_cursor")

            if not cursor:
                break

            # Rate limit: Slack 50 req/min
            time.sleep(1.2)

        return messages

    def _fetch_replies(self, channel_id: str, thread_ts: str) -> List[Dict]:
        resp = self.s.get(
            f"{self.API}/conversations.replies",
            params={"channel": channel_id, "ts": thread_ts, "limit": 200},
            timeout=30,
        )
        data = resp.json()
        if not data.get("ok"):
            return []
        msgs = data.get("messages", [])
        # Ilk mesaj parent'tir, onu atla
        return msgs[1:] if len(msgs) > 1 else []

    def _group_into_bursts(self, messages: List[Dict], gap_seconds: int = 300) -> List[List[Dict]]:
        """Ayni yazarin 5dk icindeki mesajlarini tek burst'te birlestir."""
        if not messages:
            return []

        bursts = []
        current = [messages[0]]

        for msg in messages[1:]:
            prev = current[-1]
            same_user = msg.get("user") == prev.get("user")
            time_gap = float(msg["ts"]) - float(prev["ts"])

            if same_user and time_gap < gap_seconds:
                current.append(msg)
            else:
                bursts.append(current)
                current = [msg]

        bursts.append(current)
        return bursts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--channel", help="Tek kanal ID'si (C01234...)")
    ap.add_argument("--all", action="store_true", help="Tum erisilebilir kanallar")
    ap.add_argument("--list", action="store_true", help="Kanallari listele")
    ap.add_argument("--limit", type=int, default=200)
    args = ap.parse_args()

    conn = SlackConnector()

    if args.list:
        for ch in conn.list_channels():
            print(f"  {ch['id']}  #{ch['name']}")
        return

    channels = []
    if args.all:
        channels = [ch["id"] for ch in conn.list_channels()]
    elif args.channel:
        channels = [args.channel]
    else:
        ap.error("--channel veya --all gerekli")

    for ch_id in channels:
        n = conn.sync_channel(ch_id, limit=args.limit)
        print(f"#{ch_id}: {n} chunks ingested")


if __name__ == "__main__":
    main()
