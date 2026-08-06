defmodule AgentbotCore.Modules.Agents.AgentGateway do
  @moduledoc """
  Ajan geçidi — harici ajan bağlantılarını yönetir.

  REST API, WebSocket ve A2A protokolü üzerinden
  gelen ajan bağlantılarını koordine eder.

  Phase 1'de tam WebSocket desteği eklenecek.
  """

  alias AgentbotCore.Modules.Protocol.Envelope

  @doc """
  Ajan giriş yapar — token doğrulayıp onboarding yapar.
  """
  @spec connect(map()) :: {:ok, map()} | {:error, String.t()}
  def connect(params) do
    agent_id = Map.get(params, "agent_id")
    agent_name = Map.get(params, "agent_name")

    if agent_id && agent_name do
      # TODO: AgentPresence ile kayıt
      {:ok, %{
        agent_id: agent_id,
        agent_name: agent_name,
        connected_at: DateTime.utc_now(),
        status: "connected"
      }}
    else
      {:error, "agent_id ve agent_name zorunlu"}
    end
  end

  @doc """
  Ajan mesaj gönderir — Envelope oluşturup yönlendirir.
  """
  @spec send_envelope(String.t(), map(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def send_envelope(agent_id, params, _agent_info) do
    envelope = Envelope.new([
      type: Map.get(params, "type", "message"),
      sender: agent_id,
      recipient: Map.get(params, "recipient"),
      payload: Map.get(params, "payload", %{}),
      room_id: Map.get(params, "room_id"),
      metadata: Map.get(params, "metadata", %{})
    ])

    cond do
      params["room_id"] == nil and params["recipient"] == nil ->
        {:error, "room_id veya recipient zorunlu"}

      true ->
        case envelope.room_id do
          nil ->
            AgentbotCore.PubSub.broadcast(
              "agent:#{envelope.recipient}",
              "outgoing",
              envelope
            )
            {:ok, envelope.id}

          room_id ->
            AgentbotCore.Modules.Chat.RoomServer.send_message(room_id, envelope)
            {:ok, envelope.id}
        end
    end
  end

  @doc """
  Ajan çıkış yapar.
  """
  @spec disconnect(String.t()) :: :ok
  def disconnect(agent_id) do
    AgentbotCore.PubSub.broadcast(
      "agent:#{agent_id}",
      "disconnected",
      %{agent_id: agent_id}
    )
    :ok
  end
end
