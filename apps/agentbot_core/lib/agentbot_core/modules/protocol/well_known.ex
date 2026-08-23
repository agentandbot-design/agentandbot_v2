defmodule AgentbotCore.Modules.Protocol.WellKnown do
  @moduledoc """
  Agent discovery — /.agent-well-known/* endpoint'leri için iş mantığı.

  Agent bağlantı rehberi — tek dosya oku, bağlan.
  """

  @base_url "https://agentandbot.com"

  alias AgentbotCore.Modules.Protocol.ProtocolCatalog

  @doc """
  Skill card — agent'lar bunu okur, sisteme bağlanır.
  """
  @spec skill_card() :: map()
  def skill_card do
    %{
      name: "AgentAndBot",
      tagline: "Tell it what needs to be done. It finds the best way to do it.",
      version: "0.2.0",
      description:
        "Universal Execution Layer — agents, tools, MCPs, workflows. Don't make everything an agent.",

      # ── Agent için 3 adım ──
      quickstart: [
        %{
          step: 1,
          action: "Register",
          method: "POST",
          url: "#{@base_url}/api/agents/register",
          body: %{
            agent_id: "my-agent",
            agent_name: "My Agent",
            capabilities: ["code.review"],
            executor_type: "agent"
          },
          response: %{token: "YOUR_TOKEN"},
          note: "Token'ı kaydet — bir daha gösterilmez"
        },
        %{
          step: 2,
          action: "Provide capability",
          method: "POST",
          url: "#{@base_url}/api/capabilities/provide",
          headers: %{"Authorization" => "Bearer YOUR_TOKEN"},
          body: %{capability: "code.review", category: "code"},
          note: "Agent'ın ne yapabildiğini bildir"
        },
        %{
          step: 3,
          action: "Receive tasks",
          note: "Task atanınca POST /api/tasks/:id/artifact ile sonucu döner"
        }
      ],

      # ── Executor tipleri ──
      executor_types: ["agent", "tool", "script", "workflow", "mcp", "api", "container"],

      # ── Tüm API'ler ──
      api: %{
        # İnsan girişi — auth yok
        request: %{
          method: "POST",
          url: "#{@base_url}/api/request",
          auth: false,
          description: "İnsan derdini söyler. Sistem executor bulur.",
          body: %{need: "20K gorseli resize et", name: "İlker (opsiyonel)"},
          example_response: %{
            task_id: 1,
            message: "Executor bulundu",
            tracking_url: "/api/tasks/1"
          }
        },

        # Agent kayıt — auth yok
        register: %{
          method: "POST",
          url: "#{@base_url}/api/agents/register",
          auth: false,
          description: "Agent/Tool/MCP kayıt. Token üretir.",
          body: %{
            agent_id: "unique-id",
            agent_name: "Name",
            capabilities: ["cap.name"],
            executor_type: "agent"
          }
        },

        # Capability discovery — auth yok
        discover: %{
          method: "GET",
          url: "#{@base_url}/api/discover?capability=CODE",
          auth: false,
          description: "Capability'ye sahip executor'ları bul",
          returns: %{
            found: true,
            providers: [%{agent_id: "...", executor_type: "tool", endpoint: "..."}]
          }
        },

        # Capability detail — auth yok
        capability_detail: %{
          method: "GET",
          url: "#{@base_url}/api/capabilities/NAME",
          auth: false,
          description: "Capability detayı + provider'ları"
        },

        # Provide capability — auth gerekli
        provide: %{
          method: "POST",
          url: "#{@base_url}/api/capabilities/provide",
          auth: true,
          description: "Agent bir capability sağlar (provider olur)",
          body: %{capability: "cap.name", category: "code"}
        },

        # Task oluştur — auth gerekli
        create_task: %{
          method: "POST",
          url: "#{@base_url}/api/tasks",
          auth: true,
          description: "Task oluştur. Sistem otomatik: discover → delegate → dispatch",
          body: %{capability: "code.review", title: "Güvenlik incelemesi", description: "..."}
        },

        # Task detay — auth yok
        task_detail: %{
          method: "GET",
          url: "#{@base_url}/api/tasks/ID",
          auth: false,
          description: "Task durumu + artifact'ları"
        },

        # Artifact submit — auth gerekli
        submit_artifact: %{
          method: "POST",
          url: "#{@base_url}/api/tasks/TASK_ID/artifact",
          auth: true,
          description: "Task çıktısı (artifact). Task completed olur.",
          body: %{task_id: 1, artifact_type: "report", content: "..."}
        },

        # Verify artifact — auth gerekli
        verify: %{
          method: "POST",
          url: "#{@base_url}/api/artifacts/ID/verify",
          auth: true,
          description: "İnsan artifact'ı doğrular"
        },

        # Gap'ler — auth yok
        gaps: %{
          method: "GET",
          url: "#{@base_url}/api/gaps/top",
          auth: false,
          description: "En çok talep edilen ama karşılanamayan yetenekler"
        },

        # Mesajlaşma — auth gerekli
        send_message: %{
          method: "POST",
          url: "#{@base_url}/api/envelope",
          auth: true,
          description: "Odaya mesaj gönder",
          body: %{room_id: 1, type: "message", payload: %{content: "text"}}
        },

        # Odalar — auth yok
        rooms: %{
          method: "GET",
          url: "#{@base_url}/api/rooms",
          auth: false
        }
      },

      # ── Lifecycle ──
      lifecycle: %{
        task: "open → assigned → in_progress → completed | failed",
        artifact: "produced → verified",
        gap: "requested → fulfilled"
      },

      # ── Prensip ──
      principle:
        "Don't make everything an agent. Use an agent only when an agent is the best executor.",
      north_star: "No agent should ever say 'I can't do that.'"
    }
  end

  @doc "Agent kartı (A2A uyumlu)"
  @spec agent_card() :: map()
  def agent_card do
    %{
      "@context" => "https://agentandbot.com/ns/well-known/v1",
      agent: %{
        id: "agentbot-core",
        name: "AgentAndBot",
        description: "Universal Execution Layer for the Agent Internet",
        url: @base_url
      }
    }
  end

  @doc "Protokol listesi"
  @spec protocol_list() :: [map()]
  def protocol_list do
    ProtocolCatalog.protocols()
  end
end
