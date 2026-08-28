#!/usr/bin/env python3
"""qm_mem_sync.py — QM memory notebook'larını mem.agentandbot.com'a sync eder.

Karar (Bauhaus):
- Kanal (channel:) ve org (org:) scope'lu notebook'lar → kurumsal hafızaya
- DM / kişisel (dm:, personal:) notebook'lar → SENKRONIZE EDİLMEZ (QM'de by-design izole)

QM tablosu: memory_revisions (scope_id, seq, op, body, author, at)
  op = add | rewrite ... — body içindeki fact'ler "\n" ayrıklı satırlar

Sync state: connectors/state/qm_memory_sync.json — son islenen (scope_id, seq).
Upsert: mem tarafında title+source=chat ile gider; tekrar calistirinca
ayni satirlari atlar (content hash karsilastirmasi).

Kullanim:
  export MEM_TOKEN=...
  python3 qm_mem_sync.py [--db qm] [--dry-run]
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys

MEM_URL = os.environ.get("MEM_URL", "https://mem.agentandbot.com")
MEM_TOKEN = os.environ.get("MEM_TOKEN", "")
STATE_FILE = os.path.join(os.path.dirname(__file__), "state", "qm_memory_sync.json")
QM_CONTAINER = "qm-agentandbot-pg"

# Sadece bu prefix'lerdeki scope'lar senkronize edilir
SYNC_SCOPES = ("channel:", "org:")
# Bu prefix'ler asla senkronize edilmez (kişisel/DM izolasyonu)
SKIP_SCOPES = ("dm:", "personal:", "user:")


def psql(query: str) -> list[dict]:
    """QM postgres container'ında sorgu çalıştır, JSON döndür."""
    cmd = [
        "sudo", "docker", "exec", QM_CONTAINER,
        "psql", "-U", "postgres", "-d", "qm", "-t", "-A", "-c",
        query,
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True)
    rows = []
    for line in out.stdout.strip().split("\n"):
        if line:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def load_state() -> dict:
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_seq": {}}


def save_state(state: dict) -> None:
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def fetch_revisions() -> list[dict]:
    """Yeni memory_revisions satırlarını çek (sync edilebilir scope'lar)."""
    scope_filter = ",".join(f"'{p}%'" for p in SYNC_SCOPES)
    query = (
        "SELECT json_build_object('id', id, 'scope_id', scope_id, 'seq', seq, "
        "'op', op, 'body', body, 'author', author, 'at', at) "
        "FROM memory_revisions WHERE scope_id LIKE ANY "
        f"(ARRAY[{','.join(chr(39) + p + '%' + chr(39) for p in SYNC_SCOPES)}]) "
        "ORDER BY id ASC;"
    )
    return psql(query)


def mem_ingest(content: str, title: str, project: str) -> dict:
    """mem.agentandbot.com /api/memory endpoint'ine POST at."""
    import urllib.request

    body = json.dumps({
        "content": content,
        "title": title,
        "source": "chat",
        "project": project,
    }).encode()
    req = urllib.request.Request(
        f"{MEM_URL}/api/memory",
        data=body,
        headers={
            "Authorization": f"Bearer {MEM_TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def sync(dry_run: bool = False) -> None:
    if not MEM_TOKEN:
        print("MEM_TOKEN env gerekli")
        sys.exit(1)

    state = load_state()
    revisions = fetch_revisions()

    if not revisions:
        print("Sync edilecek revision yok (memory_revisions boş veya filtre dışı)")
        return

    synced, skipped, failed = 0, 0, 0

    for rev in revisions:
        scope = rev["scope_id"]
        seq = rev["seq"]
        last = state["last_seq"].get(scope, 0)
        if seq <= last:
            skipped += 1
            continue

        # Her revision'ın fact satırlarını tek chunk olarak yaz
        body = rev.get("body", "").strip()
        if not body:
            skipped += 1
            state["last_seq"][scope] = seq
            continue

        # op=rewrite → notebook'un tam hali; add → yeni satırlar
        scope_label = scope.replace(":", "/")
        title = f"QM memory — {scope_label}"
        content = f"[{scope_label}] (rev {seq}, op={rev['op']}, author={rev.get('author') or 'unknown'})\n{body}"
        digest = hashlib.sha256(content.encode()).hexdigest()[:12]

        if dry_run:
            print(f"[dry] {scope} seq={seq} op={rev['op']} len={len(body)} hash={digest}")
        else:
            try:
                result = mem_ingest(content, title, "qm")
                ok = result.get("ok", False)
                if ok:
                    synced += 1
                else:
                    failed += 1
                    print(f"  hata ({scope} seq={seq}): {result}")
            except Exception as e:  # noqa: BLE001
                failed += 1
                print(f"  exception ({scope} seq={seq}): {e}")

        state["last_seq"][scope] = seq

    if not dry_run:
        save_state(state)

    print(f"\nSync bitti: {synced} yeni, {skipped} atlandı, {failed} hata")
    print(f"Kural: {'/'.join(SYNC_SCOPES)} → mem  |  {'/'.join(SKIP_SCOPES)} → SENKRONIZE EDILMEZ (izole)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="QM memory → mem.agentandbot.com sync")
    parser.add_argument("--dry-run", action="store_true", help="yazma, sadece göster")
    args = parser.parse_args()
    sync(dry_run=args.dry_run)
