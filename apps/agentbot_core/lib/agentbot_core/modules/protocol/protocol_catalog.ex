defmodule AgentbotCore.Modules.Protocol.ProtocolCatalog do
  @moduledoc """
  Merkezi protokol kayıt defteri — AgentAndBot discovery yüzeyleri için.

  Desteklenen tüm protokollerin listesi, discovery path'leri
  ve runtime uyumluluk bilgilerini içerir.

  Eski GovernanceCore.ProtocolCatalog'den taşındı.
  """

  @protocols [
    %{
      id: "mcp",
      name: "MCP",
      domain: "tool_access",
      purpose: "Ajanlar için standart araç, veri ve prompt erişimi.",
      status: "supported",
      discovery_paths: ["/mcp", "/skills.json"],
      supported_by_runtimes: ["hermes", "agent_zero", "openclaw", "google_agent", "manus_style"]
    },
    %{
      id: "a2a",
      name: "A2A",
      domain: "agent_messaging",
      purpose: "Ajan-ajan keşfi, görev devri ve işbirliği.",
      status: "supported",
      discovery_paths: ["/.well-known/agent.json", "/agents/{id}/.well-known/agent-card.json"],
      supported_by_runtimes: ["hermes", "openclaw", "google_agent"]
    },
    %{
      id: "acp",
      name: "ACP",
      domain: "agent_messaging",
      purpose: "REST tarzı çoklu ajan koordinasyonu ve mesaj zarfları.",
      status: "compatible_metadata",
      discovery_paths: ["/api/tasks/{id}/messages"],
      supported_by_runtimes: ["hermes", "google_agent"]
    },
    %{
      id: "anp",
      name: "ANP",
      domain: "agent_network",
      purpose: "Ağ keşfi ve ajan yetenek duyurusu.",
      status: "compatible_metadata",
      discovery_paths: ["/api/protocols", "/api/agents/{id}/protocol-profile"],
      supported_by_runtimes: ["custom_webhook", "google_agent", "openclaw"]
    },
    %{
      id: "ucp",
      name: "UCP",
      domain: "commerce",
      purpose: "Katalog, niyet ve ticaret yaşam döngüsü metadata.",
      status: "manifest_ready",
      discovery_paths: ["/api/agents/{id}/commerce", "/api/tasks/{id}/commerce-intent"],
      supported_by_runtimes: ["google_agent", "custom_webhook"]
    },
    %{
      id: "ap2",
      name: "AP2",
      domain: "payments",
      purpose: "Ajan ödeme yetkileri, harcama limitleri ve yetkilendirme metadata.",
      status: "manifest_ready",
      discovery_paths: ["/api/agents/{id}/commerce", "/api/v1/services/{slug}/verify"],
      supported_by_runtimes: ["google_agent", "hermes"]
    },
    %{
      id: "did",
      name: "DID",
      domain: "identity",
      purpose: "Ajan kimliği için merkezi olmayan tanımlayıcı metadata.",
      status: "metadata_only",
      discovery_paths: ["/api/agents/{id}/identity"],
      supported_by_runtimes: ["custom_webhook", "google_agent", "agent_zero"]
    },
    %{
      id: "ed25519",
      name: "Ed25519",
      domain: "identity",
      purpose: "Ajan kimlik doğrulama için açık anahtar türü.",
      status: "metadata_only",
      discovery_paths: ["/api/agents/{id}/identity"],
      supported_by_runtimes: ["agent_zero", "custom_webhook"]
    },
    %{
      id: "openapi_3_1",
      name: "OpenAPI 3.1",
      domain: "api_contract",
      purpose: "İnsan ve ajan istemcileri için HTTP API tanımı.",
      status: "supported",
      discovery_paths: ["/api/openapi.json"],
      supported_by_runtimes: ["hermes", "agent_zero", "openclaw", "google_agent", "custom_webhook", "manus_style", "space_agent", "minimax_agent"]
    },
    %{
      id: "json_schema",
      name: "JSON Schema",
      domain: "api_contract",
      purpose: "Yetenekler ve araçlar için tip girişi/çıkışı sözleşmeleri.",
      status: "supported",
      discovery_paths: ["/skills.json", "/api/openapi.json"],
      supported_by_runtimes: ["hermes", "agent_zero", "openclaw", "google_agent", "custom_webhook", "manus_style", "space_agent", "minimax_agent"]
    },
    %{
      id: "x402",
      name: "x402",
      domain: "payments",
      purpose: "Ödeme zorluğu metadata ve gelecekteki makine-ödeme ticareti.",
      status: "internal_credits_now",
      discovery_paths: ["/api/v1/services/{slug}/verify"],
      supported_by_runtimes: ["hermes", "openclaw", "manus_style", "custom_webhook"]
    }
  ]

  @doc "Tüm protokolleri döndürür"
  def protocols, do: @protocols

  @doc "ID ile protokol bulur"
  def get(id) do
    Enum.find(@protocols, &(&1.id == id or &1.name == id))
  end

  @doc "Tüm protokol isimlerini döndürür"
  def names, do: Enum.map(@protocols, & &1.name)

  @doc "Belirli bir runtime için desteklenen protokolleri filtreler"
  def for_runtime(runtime_id) do
    Enum.filter(@protocols, &(runtime_id in &1.supported_by_runtimes))
  end
end
