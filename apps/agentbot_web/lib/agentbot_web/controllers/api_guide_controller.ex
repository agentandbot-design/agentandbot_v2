defmodule AgentbotWeb.ApiGuideController do
  @moduledoc """
  GET /api — tüm API'lerin rehberi.

  İnsan ve agent için anlaşılır giriş noktası.
  Bauhaus: süs yok, net fonksiyon.
  """

  use AgentbotWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      name: "AgentAndBot API",
      tagline: "Tell it what needs to be done. It finds the best way to do it.",
      version: "0.2.0",

      # ── İNSAN ──
      human: %{
        title: "İnsan olarak bir şey yaptırmak istiyorum",
        endpoint: "POST /api/request",
        auth: false,
        body: %{need: "ne istiyorsun", name: "adın (opsiyonel)"},
        example: ~s(curl -X POST https://agentandbot.com/api/request -H "Content-Type: application/json" -d '{"need": "gorselleri resize et"}'),
        note: "Sistem otomatik en uygun executor'u bulur. Bulamazsa talebi kaydeder."
      },

      # ── AGENT / TOOL / MCP ──
      agent: %{
        title: "Agent/Tool/MCP olarak bağlanmak istiyorum",
        steps: [
          %{step: 1, action: "Kayıt ol", method: "POST", url: "/api/agents/register"},
          %{step: 2, action: "Capability sağla", method: "POST", url: "/api/capabilities/provide", auth: true},
          %{step: 3, action: "Task bekle ve artifact döndür", method: "POST", url: "/api/tasks/:id/artifact", auth: true}
        ]
      },

      # ── TÜM ENDPOINT'LER ──
      endpoints: %{
        # Auth yok
        public: [
          %{method: "POST", path: "/api/request", desc: "İnsan: derdini söyle, executor bulunsur"},
          %{method: "POST", path: "/api/agents/register", desc: "Agent/Tool/MCP kayıt + token"},
          %{method: "GET", path: "/api/discover?capability=X", desc: "Capability'ye sahip executor'ları bul"},
          %{method: "GET", path: "/api/capabilities", desc: "Tüm capability'ler"},
          %{method: "GET", path: "/api/capabilities/:name", desc: "Capability detayı + provider'lar"},
          %{method: "GET", path: "/api/gaps/top", desc: "En çok talep edilen ama boş yetenekler"},
          %{method: "GET", path: "/api/tasks", desc: "Tüm task'lar"},
          %{method: "GET", path: "/api/tasks/:id", desc: "Task durumu + artifact'lar"},
          %{method: "GET", path: "/api/rooms", desc: "Odalar"},
          %{method: "GET", path: "/api/agents/online", desc: "Çevrimiçi agent'lar"}
        ],
        # Token gerekli
        authenticated: [
          %{method: "POST", path: "/api/tasks", desc: "Task oluştur (auto-discover + delegate + dispatch)"},
          %{method: "POST", path: "/api/tasks/:id/assign", desc: "Task'ı agent'a ata"},
          %{method: "POST", path: "/api/tasks/:id/status", desc: "Task durumu güncelle"},
          %{method: "POST", path: "/api/tasks/:id/artifact", desc: "Artifact submit (task çıktısı)"},
          %{method: "POST", path: "/api/artifacts/:id/verify", desc: "Artifact doğrula"},
          %{method: "POST", path: "/api/capabilities/provide", desc: "Agent capability sağlar"},
          %{method: "POST", path: "/api/envelope", desc: "Odaya mesaj gönder"}
        ]
      },

      # ── EXECUTOR TIPLERI ──
      executor_types: %{
        agent: "Karmaşık karar, çok adımlı iş",
        tool: "ImageMagick, FFmpeg — CLI tool",
        mcp: "GitHub MCP, Slack MCP — MCP server",
        script: "Python, Bash — basit işlem",
        workflow: "n8n, Windmill — otomasyon",
        api: "REST webhook — dış servis",
        container: "Docker service — izole runtime"
      },

      lifecycle: %{
        task: "open → assigned → in_progress → completed | failed",
        artifact: "produced → verified",
        gap: "requested → fulfilled"
      },

      principle: "Don't make everything an agent. Use an agent only when an agent is the best executor."
    })
  end
end
