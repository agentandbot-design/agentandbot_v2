"""
Gmail → mem.agentandbot.com connector

Senkronize ettigi seyler:
- Email subject + body (plaintext) + from/to metadata
- Thread bazli degil, mail bazli chunk

Auth: GMAIL_CREDENTIALS_FILE (OAuth token JSON — gmail.readonly scope).
"""

import os
import argparse
import base64
from typing import List, Dict, Any

from mem_client import MemClient, StateStore


class GmailConnector:
    def __init__(self, mem: MemClient = None, credentials_file: str = ""):
        self.mem = mem or MemClient()
        self.credentials_file = credentials_file or os.getenv("GMAIL_CREDENTIALS_FILE", "")
        self.state = StateStore("state/gmail.json")
        self._service = None

    def _get_service(self):
        if self._service:
            return self._service

        if not self.credentials_file:
            raise ValueError("GMAIL_CREDENTIALS_FILE env must be set")

        from google.oauth2.credentials import Credentials
        from googleapiclient.discovery import build

        creds = Credentials.from_authorized_user_file(
            self.credentials_file,
            scopes=["https://www.googleapis.com/auth/gmail.readonly"],
        )

        self._service = build("gmail", "v1", credentials=creds)
        return self._service

    def sync_mailbox(self, query: str = "", max_emails: int = 100) -> int:
        """Mailbox'i senkronize et.

        query: Gmail arama sorgusu (örn "from:boss", "label:inbox", "newer_than:30d")
        """
        service = self._get_service()

        # HistoryId yerine after timestamp kullan (historyId per-account)
        last_history = self.state.get("last_history_id")
        query_with_date = query
        if last_history:
            # Son senkronizasyondan sonra sadece yeni mailler
            from datetime import datetime, timedelta

            last_dt = datetime.fromtimestamp(last_history)
            date_str = last_dt.strftime("%Y/%m/%d")
            query_with_date = f"{query} after:{date_str}".strip()

        results = (
            service.users()
            .messages()
            .list(userId="me", q=query_with_date, maxResults=min(max_emails, 500))
            .execute()
        )

        messages = results.get("messages", [])
        count = 0

        for msg_ref in messages[:max_emails]:
            msg = (
                service.users()
                .messages()
                .get(userId="me", id=msg_ref["id"], format="full")
                .execute()
            )

            headers = {h["name"]: h["value"] for h in msg["payload"]["headers"]}
            subject = headers.get("Subject", "(no subject)")
            from_addr = headers.get("From", "unknown")
            to_addr = headers.get("To", "unknown")
            date = headers.get("Date", "")

            body = self._extract_body(msg["payload"])

            # Attachment adlarini da metadata'ya koy
            attachments = self._extract_attachment_names(msg["payload"])

            content = f"Subject: {subject}\nFrom: {from_addr}\nTo: {to_addr}\nDate: {date}\n\n{body}"

            self.mem.ingest(
                {
                    "content": self.mem.normalize(content),
                    "source": "gmail",
                    "project": "email",
                    "title": subject,
                    "metadata": {
                        "type": "email",
                        "message_id": msg["id"],
                        "thread_id": msg["threadId"],
                        "from": from_addr,
                        "to": to_addr,
                        "date": date,
                        "attachments": attachments,
                        "labels": msg.get("labelIds", []),
                    },
                }
            )
            count += 1

        # Son mailin internalDate'ini kaydet
        if messages:
            last_msg = (
                service.users()
                .messages()
                .get(userId="me", id=messages[-1]["id"], format="metadata")
                .execute()
            )
            internal_date = int(last_msg.get("internalDate", "0")) / 1000
            self.state.set("last_history_id", internal_date)

        return count

    def _extract_body(self, payload: Dict[str, Any]) -> str:
        """MIME payload'tan plaintext body cikart."""
        import email as email_lib
        from email import policy

        # Basit yol: text/plain part bul
        if payload.get("mimeType") == "text/plain":
            data = payload["body"].get("data", "")
            if data:
                return base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")

        # multipart ise recursive in
        parts = payload.get("parts", [])
        for part in parts:
            if part.get("mimeType") == "text/plain":
                data = part["body"].get("data", "")
                if data:
                    return base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")
            elif part.get("mimeType", "").startswith("multipart/"):
                inner = self._extract_body(part)
                if inner:
                    return inner

        return ""

    def _extract_attachment_names(self, payload: Dict[str, Any]) -> List[str]:
        names = []
        for part in payload.get("parts", []):
            filename = part.get("filename")
            if filename:
                names.append(filename)
        return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", default="", help="Gmail arama sorgusu")
    ap.add_argument("--max", type=int, default=100)
    args = ap.parse_args()

    conn = GmailConnector()
    n = conn.sync_mailbox(query=args.query, max_emails=args.max)
    print(f"emails: {n} ingested")


if __name__ == "__main__":
    main()
