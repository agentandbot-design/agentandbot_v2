defmodule AgentbotCore.Modules.Agents.AgentPresence do
  @moduledoc """
  Ajan varlığı — çevrimiçi/çevrimdışı durumu takibi.

  PubSub üzerinden gerçek zamanlı durum güncellemesi yapar.
  """

  @doc "Ajan çevrimiçi olarak kaydeder"
  @spec track_online(String.t(), String.t()) :: :ok
  def track_online(agent_id, agent_name) do
    AgentbotCore.PubSub.broadcast(
      "presence",
      "agent_online",
      %{agent_id: agent_id, agent_name: agent_name, timestamp: DateTime.utc_now()}
    )
    :ok
  end

  @doc "Ajan çevrimdışı olarak kaydeder"
  @spec track_offline(String.t()) :: :ok
  def track_offline(agent_id) do
    AgentbotCore.PubSub.broadcast(
      "presence",
      "agent_offline",
      %{agent_id: agent_id, timestamp: DateTime.utc_now()}
    )
    :ok
  end

  @doc "Tüm çevrimiçi ajanları döndürür"
  @spec list_online() :: [map()]
  def list_online do
    # TODO: ETS tabanlı tracking implementasyonu
    []
  end
end
