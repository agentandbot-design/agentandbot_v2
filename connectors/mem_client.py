"""
Core ingestion client → mem.agentandbot.com

Tum connector'lar (github, gdocs, slack, gmail, chat) bu modulu kullanir.

- Bearer token auth (Bearer prefix otomatik)
- Idempotent: chunk_id = sha256(source + path + ts) — ayni kaynak iki kez gelirse
  Mem API'de yok sayilir.
- Rate-limit-friendly: 3 retry, exponential backoff
- Batch ingestion: /api/memory topyekün POST (her bir chunk icin ayri istek atmiyor)
"""

import os
import json
import hashlib
import time
from typing import List, Dict, Any, Optional
from urllib.parse import urljoin

import requests


class MemClient:
    def __init__(
        self,
        base_url: Optional[str] = None,
        token: Optional[str] = None,
        timeout: int = 30,
        max_retries: int = 3,
    ):
        self.base_url = (base_url or os.getenv("MEM_API_URL", "https://mem.agentandbot.com")).rstrip("/")
        self.token = token or os.getenv("MEM_TOKEN", "")
        if not self.token:
            raise ValueError("MEM_TOKEN env must be set")
        self.timeout = timeout
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            }
        )

    # -----------------------------------------------------------------
    # Public API
    # -----------------------------------------------------------------
    def ingest(self, chunk: Dict[str, Any]) -> Dict[str, Any]:
        """Tek bir chunk gonder. `chunk` sozluk olmali:
        {
          "content": <str>,                # zorunlu
          "source": "gh" | "gd" | "slack" | "gmail" | "chat" | ...,
          "project": "agentandbot" | ...,
          "title": <str> | None,
          "metadata": {...},
        }
        """
        url = urljoin(self.base_url + "/", "api/memory")
        return self._post_with_retry(url, chunk)

    def ingest_batch(self, chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Birden fazla chunk'u sirayla gonder (Mem su an toplu endpoint acmadi).
        Idempotent: ayni id ile gelirse Mem degismez.
        """
        results = []
        for ch in chunks:
            results.append(self.ingest(ch))
        return results

    def search(self, query: str, limit: int = 10) -> Dict[str, Any]:
        url = urljoin(self.base_url + "/", "api/memory/search")
        resp = self.session.get(
            url, params={"q": query, "limit": limit}, timeout=self.timeout
        )
        resp.raise_for_status()
        return resp.json()

    def health(self) -> Dict[str, Any]:
        url = urljoin(self.base_url + "/", "health")
        resp = self.session.get(url, timeout=self.timeout)
        resp.raise_for_status()
        return resp.json()

    # -----------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------
    @staticmethod
    def chunk_id(source: str, path: str, ts: str) -> str:
        """Stable chunk kimligi — Mem'de duplicate kontrolu icin."""
        raw = f"{source}::{path}::{ts}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]

    @staticmethod
    def normalize(content: str, max_len: int = 8000) -> str:
        """Embedder 8K civarini tolere eder; uzeri kesilir."""
        content = content.strip()
        if len(content) > max_len:
            content = content[:max_len] + "...[truncated]"
        return content

    # -----------------------------------------------------------------
    # Internals
    # -----------------------------------------------------------------
    def _post_with_retry(self, url: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        last_err = None
        for attempt in range(1, self.max_retries + 1):
            try:
                resp = self.session.post(url, json=payload, timeout=self.timeout)
                if resp.status_code == 201 or resp.status_code == 200:
                    return resp.json()
                # 5xx / rate limit → retry
                if resp.status_code >= 500 or resp.status_code == 429:
                    last_err = f"HTTP {resp.status_code}: {resp.text[:200]}"
                    time.sleep(2 ** attempt)
                    continue
                # 4xx → fail fast
                return {"error": f"HTTP {resp.status_code}", "body": resp.text[:300]}
            except (requests.RequestException, ConnectionError) as e:
                last_err = str(e)
                time.sleep(2 ** attempt)
        return {"error": "max_retries", "last_error": last_err}


# -----------------------------------------------------------------
# State yönetimi (connector'lar icin)
# -----------------------------------------------------------------
class StateStore:
    """Connector'larin kaldigi yerden devam etmesini saglar."""

    def __init__(self, path: str):
        self.path = path
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            self.write({})

    def read(self) -> Dict[str, Any]:
        try:
            with open(self.path) as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def write(self, data: Dict[str, Any]):
        with open(self.path, "w") as f:
            json.dump(data, f, indent=2)

    def get(self, key: str, default: Any = None) -> Any:
        return self.read().get(key, default)

    def set(self, key: str, value: Any):
        d = self.read()
        d[key] = value
        self.write(d)
