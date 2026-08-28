#!/usr/bin/env python3
"""connector_registry.py — mem.agentandbot.com connector manifest'i.

Her connector plug-and-play: tek dosya, tek komut.
Durum: ready (calisiyor) | awaiting-credentials | planned

Kullanim:
  python3 connector_registry.py                 # tum connector'lari listele
  python3 connector_registry.py --status ready  # sadece calisanlari
"""
import argparse
import json

CONNECTORS = [
    {
        "id": "github",
        "script": "github_connector.py",
        "source": "github",
        "status": "ready",
        "credentials": [],
        "description": "GitHub repo docs/issues/PR metinlerini mem'e ingest eder",
        "example": "python3 github_connector.py --repo agentandbot-design/agentandbot_v2 --all",
    },
    {
        "id": "gdocs",
        "script": "gdocs_connector.py",
        "source": "gdocs",
        "status": "awaiting-credentials",
        "credentials": [
            "GOOGLE_CREDENTIALS_FILE — service account JSON (Drive API erişimi)",
            "GDOCS_FOLDER_ID — izlenecek Drive klasörünün ID'si",
        ],
        "description": "Google Drive klasöründeki Docs/Sheet'leri metin olarak çeker",
        "example": "python3 gdocs_connector.py --folder FOLDER_ID",
    },
    {
        "id": "gmail",
        "script": "gmail_connector.py",
        "source": "gmail",
        "status": "awaiting-credentials",
        "credentials": [
            "GMAIL_CREDENTIALS_FILE — OAuth client JSON (gmail.readonly)",
            "GMAIL_TOKEN_FILE — ilk OAuth akışından sonra oluşur",
        ],
        "description": "Gmail sorgusuna uyan e-postaları indeksler",
        "example": 'python3 gmail_connector.py --query "newer_than:30d"',
    },
    {
        "id": "slack",
        "script": "slack_connector.py",
        "source": "slack",
        "status": "awaiting-credentials",
        "credentials": [
            "SLACK_BOT_TOKEN — xoxb-... (channels:history + channels:read)",
            "SLACK_CHANNELS — izlenecek kanal ID listesi (virgülle)",
        ],
        "description": "Slack kanal geçmişlerini mem'e yazar",
        "example": "python3 slack_connector.py --channel C123ABC",
    },
    {
        "id": "chat",
        "script": "chat_connector.py",
        "source": "chat",
        "status": "ready",
        "credentials": [],
        "description": "JSONL sohbet loglarını okur ve indeksler",
        "example": "python3 chat_connector.py --file logs.jsonl",
    },
    {
        "id": "qm-memory",
        "script": "qm_mem_sync.py",
        "source": "chat",
        "status": "ready",
        "credentials": ["MEM_TOKEN"],
        "description": "QM kanal/org notebook'larını mem'e sync eder (DM'ler hariç)",
        "example": "python3 qm_mem_sync.py --dry-run",
    },
    {
        "id": "aab-rooms",
        "script": "aab_rooms_sync.py",
        "source": "chat",
        "status": "ready",
        "credentials": ["MEM_TOKEN"],
        "description": "AgentAndBot oda mesajlarını mem'e sync eder (agent konuşmaları)",
        "example": "python3 aab_rooms_sync.py",
    },
    {
        "id": "folder",
        "script": "folder_connector.py",
        "source": "doc",
        "status": "ready",
        "credentials": [],
        "description": "Lokal klasördeki .md/.txt/.json dosyalarını indeksler",
        "example": "python3 folder_connector.py --path /data/docs --project runbook",
    },
    {
        "id": "website",
        "script": "website_connector.py",
        "source": "doc",
        "status": "ready",
        "credentials": [],
        "description": "Website haritasını crawl edip tüm sayfaları indeksler",
        "example": "python3 website_connector.py --site https://e-any.online --max 200",
    },
    {
        "id": "teams",
        "script": None,
        "source": "chat",
        "status": "planned",
        "credentials": [
            "MS_CLIENT_ID — Azure AD app registration",
            "MS_CLIENT_SECRET — app secret",
            "MS_TENANT_ID — tenant",
            "MS_USER veya MS_TEAM/MS_CHANNEL — izlenecek hedef",
        ],
        "description": "MS Teams kanal mesajları (Graph API channelMessages)",
        "example": "python3 teams_connector.py --team X --channel Y",
    },
    {
        "id": "gsheets",
        "script": None,
        "source": "gdocs",
        "status": "planned",
        "credentials": [
            "GOOGLE_CREDENTIALS_FILE — gdocs ile aynı service account",
            "GSHEETS_IDS — izlenecek spreadsheet ID listesi",
        ],
        "description": "Google Sheets satırlarını tablo metni olarak indeksler",
        "example": "python3 gsheets_connector.py --ids ID1,ID2",
    },
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", choices=["ready", "awaiting-credentials", "planned"])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    items = CONNECTORS if not args.status else [c for c in CONNECTORS if c["status"] == args.status]

    if args.json:
        print(json.dumps(items, indent=2, ensure_ascii=False))
        return

    ready = sum(1 for c in CONNECTORS if c["status"] == "ready")
    waiting = sum(1 for c in CONNECTORS if c["status"] == "awaiting-credentials")
    planned = sum(1 for c in CONNECTORS if c["status"] == "planned")

    print(f"mem.agentandbot.com connector durumu: {ready} hazır · {waiting} credential bekliyor · {planned} planlı\n")
    for c in items:
        icon = {"ready": "✅", "awaiting-credentials": "🔑", "planned": "⏳"}[c["status"]]
        print(f"{icon} {c['id']:16} {c['description']}")
        if c["credentials"]:
            for cred in c["credentials"]:
                print(f"      🔑 {cred}")
        print(f"      $ {c['example']}")
        print()


if __name__ == "__main__":
    main()
