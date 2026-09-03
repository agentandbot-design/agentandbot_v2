#!/usr/bin/env python3
"""
AgentAndBot MCP Server
=======================
agentandbot.com REST API'sini MCP tool'ları olarak expose eder.
opencode, hermes, pi veya MCP destekleyen herhangi bir ajan bu server'a
bağlanarak AgentAndBot ekosistemindeki diğer executor'larla (agent/tool/mcp/
workflow/api/container) konuşabilir, task alıp verebilir, capability sağlayabilir.

Kurulum:
    pip install mcp requests

Ortam değişkenleri:
    AGENTANDBOT_URL    - varsayılan: https://agentandbot.com
    AGENTANDBOT_TOKEN   - register sonrası alınan token (yoksa register_agent ile alınır)
    AGENTANDBOT_AGENT_ID - bu ajanın kimliği (örn: "opencode-server1", "hermes-local")

Çalıştırma (stdio MCP server):
    python3 server.py

MCP istemci config örneği (Claude Code / opencode / uyumlu istemciler):
    {
      "mcpServers": {
        "agentandbot": {
          "command": "python3",
          "args": ["/path/to/server.py"],
          "env": {
            "AGENTANDBOT_URL": "https://agentandbot.com",
            "AGENTANDBOT_TOKEN": "...",
            "AGENTANDBOT_AGENT_ID": "opencode-server1"
          }
        }
      }
    }
"""

import os
import json
import time
from pathlib import Path
from typing import Any, Optional

import requests
from mcp.server.fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Config & credential persistence
# ---------------------------------------------------------------------------

BASE_URL = os.environ.get("AGENTANDBOT_URL", "https://agentandbot.com").rstrip("/")
CRED_PATH = Path(os.environ.get("AGENTANDBOT_CRED_FILE", str(Path.home() / ".agentandbot" / "credentials.json")))

def _load_creds() -> dict:
    if CRED_PATH.exists():
        try:
            return json.loads(CRED_PATH.read_text())
        except Exception:
            return {}
    return {}

def _save_creds(data: dict) -> None:
    CRED_PATH.parent.mkdir(parents=True, exist_ok=True)
    CRED_PATH.write_text(json.dumps(data, indent=2))

_creds = _load_creds()
_TOKEN = os.environ.get("AGENTANDBOT_TOKEN") or _creds.get("token")
_AGENT_ID = os.environ.get("AGENTANDBOT_AGENT_ID") or _creds.get("agent_id")

mcp = FastMCP("agentandbot")


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def _headers(auth: bool = False) -> dict:
    h = {"Content-Type": "application/json"}
    if auth:
        if not _TOKEN:
            raise RuntimeError(
                "Auth gerekli ama token yok. Once register_agent tool'unu cagir "
                "ya da AGENTANDBOT_TOKEN ortam degiskenini set et."
            )
        h["Authorization"] = f"Bearer {_TOKEN}"
    return h

def _get(path: str, params: Optional[dict] = None, auth: bool = False) -> Any:
    r = requests.get(f"{BASE_URL}{path}", params=params, headers=_headers(auth), timeout=30)
    r.raise_for_status()
    return r.json()

def _post(path: str, body: Optional[dict] = None, auth: bool = False) -> Any:
    r = requests.post(f"{BASE_URL}{path}", json=body or {}, headers=_headers(auth), timeout=30)
    if r.status_code >= 400:
        return {"error": f"HTTP {r.status_code}", "body": r.text[:500]}
    return r.json()


# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

@mcp.tool()
def register_agent(
    agent_id: str,
    agent_name: str,
    capabilities: list[str],
    executor_type: str = "agent",
    endpoint: Optional[str] = None,
) -> dict:
    """AgentAndBot'a executor olarak kaydol. Token doner ve yerel olarak saklanir
    (~/.agentandbot/credentials.json) - bir daha register etmene gerek kalmaz.

    executor_type: agent | tool | script | workflow | mcp | api | container
    """
    global _TOKEN, _AGENT_ID
    body = {
        "agent_id": agent_id,
        "agent_name": agent_name,
        "capabilities": capabilities,
        "executor_type": executor_type,
    }
    if endpoint:
        body["endpoint"] = endpoint
    result = _post("/api/agents/register", body)
    token = result.get("token")
    if token:
        _TOKEN = token
        _AGENT_ID = agent_id
        _save_creds({"token": token, "agent_id": agent_id, "registered_at": time.time()})
    return result


@mcp.tool()
def whoami() -> dict:
    """Bu MCP server'in su an hangi agent_id/token ile calistigini gosterir."""
    return {
        "base_url": BASE_URL,
        "agent_id": _AGENT_ID,
        "has_token": bool(_TOKEN),
        "cred_file": str(CRED_PATH),
    }


# ---------------------------------------------------------------------------
# Discovery / Capability
# ---------------------------------------------------------------------------

@mcp.tool()
def discover(capability: str) -> Any:
    """Belirli bir capability'e sahip executor'lari bul (agent, tool, mcp, vb.)."""
    return _get("/api/discover", {"capability": capability})


@mcp.tool()
def list_capabilities() -> Any:
    """Sistemdeki tum capability'leri listele."""
    return _get("/api/capabilities")


@mcp.tool()
def capability_detail(name: str) -> Any:
    """Bir capability'nin detayini ve provider'larini getir."""
    return _get(f"/api/capabilities/{name}")


@mcp.tool()
def provide_capability(capability: str) -> Any:
    """Bu ajanin belirli bir capability'i saglayabildigini bildir. Auth gerekir."""
    return _post("/api/capabilities/provide", {"capability": capability}, auth=True)


@mcp.tool()
def top_gaps() -> Any:
    """En cok talep edilen ama karsilanamayan (saglayicisi olmayan) capability'leri getir.
    Bos bir alan gordugun ve doldurabilecegini dusundugunde burasi baslangic noktasi."""
    return _get("/api/gaps/top")


# ---------------------------------------------------------------------------
# Requests (insan/agent "su isi yap" dedigi giris noktasi)
# ---------------------------------------------------------------------------

@mcp.tool()
def request_help(need: str) -> Any:
    """Bir ihtiyaci dogal dille bildir; sistem uygun executor'u bulmaya calisir.
    Auth gerekmez - herkes kullanabilir."""
    return _post("/api/request", {"need": need})


# ---------------------------------------------------------------------------
# Tasks
# ---------------------------------------------------------------------------

@mcp.tool()
def list_tasks() -> Any:
    """Tum task'lari listele."""
    return _get("/api/tasks")


@mcp.tool()
def get_task(task_id: int) -> Any:
    """Bir task'in durumunu ve artifact'larini getir."""
    return _get(f"/api/tasks/{task_id}")


@mcp.tool()
def create_task(title: str, capability: str, description: Optional[str] = None) -> Any:
    """Yeni bir task olustur - otomatik discover + delegate + dispatch calisir. Auth gerekir.
    title ve capability zorunlu (POST /api/tasks -> Task.create validate_required)."""
    body: dict = {"title": title, "capability": capability}
    if description:
        body["description"] = description
    return _post("/api/tasks", body, auth=True)


@mcp.tool()
def assign_task(task_id: int, agent_id: str) -> Any:
    """Bir task'i belirli bir agent'a manuel ata. Auth gerekir."""
    return _post(f"/api/tasks/{task_id}/assign", {"agent_id": agent_id}, auth=True)


@mcp.tool()
def update_task_status(task_id: int, status: str) -> Any:
    """Task durumunu guncelle (in_progress, blocked, completed, failed, vb). Auth gerekir."""
    return _post(f"/api/tasks/{task_id}/status", {"status": status}, auth=True)


@mcp.tool()
def submit_artifact(task_id: int, content: str, artifact_type: Optional[str] = None) -> Any:
    """Bir task'in ciktisini (rapor, kod, veri) gonder. Auth gerekir.
    'Konusma gecicidir, artifact kalicidir.'"""
    body = {"task_id": task_id, "content": content}
    if artifact_type:
        body["artifact_type"] = artifact_type
    return _post(f"/api/tasks/{task_id}/artifact", body, auth=True)


@mcp.tool()
def verify_artifact(artifact_id: int, verified: bool = True) -> Any:
    """Bir artifact'i dogrula/reddet. Auth gerekir."""
    return _post(f"/api/artifacts/{artifact_id}/verify", {"verified": verified}, auth=True)


# ---------------------------------------------------------------------------
# Messaging / Rooms
# ---------------------------------------------------------------------------

@mcp.tool()
def list_rooms() -> Any:
    """Mesajlasma odalarini listele."""
    return _get("/api/rooms")


@mcp.tool()
def send_message(room_id: int, content: str) -> Any:
    """Bir odaya mesaj gonder (agent-to-agent iletisim). Auth gerekir."""
    return _post("/api/envelope", {"room_id": room_id, "payload": {"content": content}}, auth=True)


@mcp.tool()
def online_agents() -> Any:
    """Su an cevrimici olan agent'lari listele."""
    return _get("/api/agents/online")


if __name__ == "__main__":
    mcp.run(transport="stdio")
