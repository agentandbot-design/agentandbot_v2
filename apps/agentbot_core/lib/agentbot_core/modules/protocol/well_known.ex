defmodule AgentbotCore.Modules.Protocol.WellKnown do
  @moduledoc """
  Agent discovery — /.agent-well-known/* endpoint'leri için iş mantığı.

  Ajan keşfi, yetenek duyurusu ve protokol listeleme.
  A2A protokol uyumlu discovery yüzeyi.
  """

  alias AgentbotCore.Modules.Protocol.ProtocolCatalog
  alias AgentbotCore.Modules.Protocol.EventTaxonomy

  @doc """
  Yetenek kartını döndürür (skill discovery).
  """
  @spec skill_card() :: map()
  def skill_card do
    %{
      "@context" => "https://agentandbot.com/ns/well-known/v1",
      agent: %{
        name: "AgentAndBot",
        version: "0.1.0",
        description: "Çoklu ajan koordinasyon ve mesajlaşma platformu",
        capabilities: capabilities(),
        protocols: Enum.map(ProtocolCatalog.protocols(), & &1.id)
      },
      event_taxonomy: Enum.map(EventTaxonomy.mcp_event_types(), fn {method, type} ->
        %{method: method, type: type, label: EventTaxonomy.label(type)}
      end),
      discovery_paths: [
        "/.agent-well-known/skill",
        "/.agent-well-known/agent.json",
        "/.agent-well-known/protocols"
      ]
    }
  end

  @doc """
  Agent kartını döndürür (agent discovery).
  """
  @spec agent_card() :: map()
  def agent_card do
    %{
      "@context" => "https://agentandbot.com/ns/well-known/v1",
      agent: %{
        id: "agentbot-core",
        name: "AgentAndBot Core",
        description: "Merkezi koordinasyon ajanı",
        url: "http://localhost:4000"
      },
      protocols: Enum.map(ProtocolCatalog.protocols(), &Map.take(&1, [:id, :name, :domain, :status]))
    }
  end

  @doc """
  Desteklenen protokoller listesini döndürür.
  """
  @spec protocol_list() :: [map()]
  def protocol_list do
    ProtocolCatalog.protocols()
  end

  # Desteklenen yetenekler
  defp capabilities do
    [
      "chat.rooms",
      "chat.messages",
      "agents.gateway",
      "agents.presence",
      "protocol.envelope",
      "security.auth",
      "security.credentials"
    ]
  end
end
