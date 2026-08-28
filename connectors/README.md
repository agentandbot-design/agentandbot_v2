# mem.agentandbot.com Connectors

Tüm kaynaklar (GitHub, Google Docs, Slack, Email, Chat) buradan
mem.agentandbot.com'a yazılır. Agent'lar tek endpoint'ten sorgular.

## Mimari

```
[GitHub]  [Google Docs]  [Slack]  [Gmail]  [Chat Logs]
    \         |          |         |        /
     \        |          |         |       /
   ───────────────────────────────────────────
        ↓
   ┌────────────────────────────┐
   │  connectors/run.py         │  ← bu script
   │                            │
   │  GitHub → API → fetch      │
   │  Google → API → fetch      │
   │  Slack → API → fetch       │
   │  Gmail → API → fetch       │
   │                            │
   │  Mem API'ye POST           │
   └────────────────────────────┘
        ↓
   POST https://mem.agentandbot.com/api/memory
   Authorization: Bearer ***" src="gh", "gd", "slack", "gmail"
   Body: {"content": "...", "source": "...", "project": "...", "title": "...", "metadata": {...}}
```

## Kurulum

```bash
cd /data/agentandbot_com/connectors
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env'i doldur: MEM_API_URL, MEM_TOKEN, kaynak API anahtarlari
```

## Calistirma

```bash
# Tum connectorlar (onceki calismanin uzerinden, sadece delta)
python3 run.py --all

# Sadece bir kaynak
python3 run.py --source github --repo agentandbot-design/agentandbot_v2
python3 run.py --source gdocs --folder-id FOLDER_ID
python3 run.py --source slack --channel C01234
python3 run.py --source gmail --query "from:boss subject:kritik"
python3 run.py --source chat --log-path /var/log/chat.log
```

## Connector Listesi

| Kaynak | Connector | Auth | Sync |
|--------|-----------|------|------|
| GitHub  | github_connector.py | PAT / GitHub App | PR, Issue, Comment, File |
| Google Docs | gdocs_connector.py | OAuth service account veya user OAuth | Doc text + revision |
| Slack  | slack_connector.py | Bot token (xoxb) | Channel messages + threads |
| Gmail  | gmail_connector.py | OAuth user | Mail subject + body |
| Chat logs | chat_connector.py | dosya okuma | Log line → chunk |

## Onceki state

Her connector `state/<source>_cursor.json` dosyasi tutar (son gorulen
PR/commit/timestamp). Idempotent ingestion: ayni kaynak iki kez gelirse
ikincisi sadece delta'yi alip ingestion yapar.
