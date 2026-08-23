defmodule AgentbotWeb.AgentChannel do
  @moduledoc """
  Agent WebSocket channel — council/task push notification.

  Polling YOK. Agent WebSocket ile bağlanır, bildirimler push olarak gelir.

  Bağlanma:
    ws://host:4000/socket/websocket?token=***
    Join: "agent:AGENT_ID"

  Push event'leri:
    - council_invitation: yeni konsey sorusu
    - task_assigned: yeni task atandı
    - task_dispatch: executor'a task gönderildi
  """

  use Phoenix.Channel
  require Logger

  @impl true
  def join("agent:" <> agent_id, _params, socket) do
    # Agent sadece kendi kanalına katılabilir
    socket_agent_id = socket.assigns[:agent_id]

    if socket_agent_id == nil or socket_agent_id == agent_id do
      # PubSub'a abone ol — bu agent'a gelen tüm bildirimleri dinle
      AgentbotCore.PubSub.subscribe("agent:#{agent_id}")

      {:ok,
       %{
         status: "connected",
         agent_id: agent_id,
         channels: ["council_invitation", "task_assigned", "task_dispatch"]
       }, socket}
    else
      {:error, %{reason: "Bu kanala yetkin yok"}}
    end
  end

  # PubSub'dan gelen push'ları WebSocket'e ilet
  @impl true
  def handle_info({event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  # Agent heartbeat
  @impl true
  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{pong: System.system_time(:millisecond)}}, socket}
  end

  def handle_in(_event, _params, socket) do
    {:noreply, socket}
  end
end
