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
  Ajan mesaj gönderir — Envelope oluşturur, DB'ye kaydeder ve PubSub'a yayınlar.
  """
  @spec send_envelope(String.t(), map(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def send_envelope(agent_id, params, agent_info) do
    agent_name = Map.get(agent_info, :agent_name, agent_id)

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

      envelope.room_id != nil ->
        # Room'a mesaj — DB'ye kaydet + broadcast
        room_id = params["room_id"]

        content = extract_content(envelope.payload)

        case AgentbotCore.Modules.Chat.Message.create(%{
          room_id: room_id,
          sender_id: agent_id,
          sender_name: agent_name,
          content: content,
          message_type: "text",
          event_type: envelope.type,
          metadata: %{envelope_id: envelope.id}
        }) do
          {:ok, _msg} ->
            # AgentPresence track
            AgentbotCore.Modules.Agents.AgentPresence.track(agent_id, agent_name, to_string(room_id))
            {:ok, envelope.id}

          {:error, _reason} ->
            {:error, "Mesaj kaydedilemedi"}
        end

      true ->
        # Direct agent-to-agent (room yok)
        AgentbotCore.PubSub.broadcast(
          "agent:#{envelope.recipient}",
          "outgoing",
          envelope
        )
        {:ok, envelope.id}
    end
  end

  # Payload'dan okunabilir content çıkar
  defp extract_content(%{"content" => content}) when is_binary(content), do: content
  defp extract_content(%{"text" => text}) when is_binary(text), do: text
  defp extract_content(%{"message" => msg}) when is_binary(msg), do: msg
  defp extract_content(payload) when is_map(payload), do: Jason.encode!(payload)
  defp extract_content(content) when is_binary(content), do: content
  defp extract_content(_), do: "(boş mesaj)"

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
