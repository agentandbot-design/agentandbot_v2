#!/usr/bin/env python3
"""aab_rooms_sync.py — AgentAndBot oda mesajlarını mem.agentandbot.com'a sync eder.

AAB DB (core-postgres/agentbot_dev): rooms + messages tabloları.
Her oda bir konuşma kanalı — mesajlar source=chat olarak indexlenir.

State: state/aab_rooms_sync.json (last message id per room).
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.request

MEM_URL = os.environ.get("MEM_URL", "https://mem.agentandbot.com")
MEM_TOKEN = os.environ.get("MEM_TOKEN", "")
STATE_FILE = os.path.join(os.path.dirname(__file__), "state", "aab_rooms_sync.json")
PG_CONTAINER = "core-postgres"
DB = "agentbot_dev"


def psql(query: str) -> list[dict]:
    cmd = ["sudo", "docker", "exec", PG_CONTAINER, "psql", "-U", "postgres", "-d", DB, "-t", "-A", "-c", query]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return [json.loads(l) for l in out.stdout.strip().split("\n") if l]


def load_state():
    if os.path.exists(STATE_FILE):
        return json.load(open(STATE_FILE))
    return {"last_id": {}}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    json.dump(state, open(STATE_FILE, "w"), indent=2)


def mem_ingest(content, title, project):
    body = json.dumps({"content": content, "title": title, "source": "chat", "project": project}).encode()
    req = urllib.request.Request(
        f"{MEM_URL}/api/memory", data=body,
        headers={"Authorization": f"Bearer {MEM_TOKEN}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def sync(dry_run=False, batch=20):
    if not MEM_TOKEN:
        print("MEM_TOKEN gerekli"); sys.exit(1)

    rooms = psql("SELECT json_build_object('id', id, 'name', name) FROM rooms ORDER BY id")
    if not rooms:
        print("Oda yok"); return

    state = load_state()
    total, ingested = 0, 0

    for room in rooms:
        rid = room["id"]
        rname = room.get("name") or f"room-{rid}"
        last = state["last_id"].get(str(rid), 0)
        msgs = psql(
            f"SELECT json_build_object('id', id, 'sender_name', sender_name, 'content', content, "
            f"'inserted_at', inserted_at) FROM messages WHERE room_id = {rid} AND id > {last} "
            f"ORDER BY id ASC LIMIT {batch}")
        total += len(msgs)

        if not msgs:
            continue

        # mesajları tek chunk'ta birleştir (bağlam korunur)
        lines = [f"AAB odası: {rname}"]
        for m in msgs:
            who = m.get("sender_name") or m.get("sender_id") or "unknown"
            content = (m.get("content") or "").strip()
            if content:
                lines.append(f"{who}: {content}")

        content_text = "\n".join(lines)
        if dry_run:
            print(f"[dry] room={rname} yeni={len(msgs)} karakter={len(content_text)}")
        else:
            try:
                res = mem_ingest(content_text, f"AAB: {rname}", "agentandbot")
                if res.get("ok"):
                    ingested += 1
                else:
                    print(f"  hata ({rname}): {res}")
            except Exception as e:
                print(f"  exception ({rname}): {e}")

        state["last_id"][str(rid)] = msgs[-1]["id"]

    if not dry_run:
        save_state(state)
    print(f"\nSync: {len(rooms)} oda, {total} yeni mesaj, {ingested} chunk yazıldı")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--batch", type=int, default=20)
    a = p.parse_args()
    sync(a.dry_run, a.batch)
