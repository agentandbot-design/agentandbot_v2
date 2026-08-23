defmodule AgentbotWeb.RoomChannel do
  @moduledoc """
  Oda WebSocket kanalı — gerçek zamanlı mesajlaşma.

  Client join olduğunda PubSub topic'ine abone olur.
  Gelen mesajları DB'ye kaydeder ve odaya yayınlar.
  """

  use Phoenix.Channel
  require Logger

  alias AgentbotCore.Modules.Chat.Message

  alias AgentbotCore.Modules.Chat.RoomSupervisor

  @impl true
  def join("room:" <> room_id, _params, socket) do
    AgentbotCore.PubSub.subscribe("room:#{room_id}")
    AgentbotCore.PubSub.subscribe("human:#{room_id}")

    # Oda sürecini başlat (yoksa)
    RoomSupervisor.start_room(room_id)

    send(self(), {:after_join, room_id})
    {:ok, %{room_id: room_id, status: "joined"}, socket}
  end

  @impl true
  def handle_info({:after_join, room_id}, socket) do
    # Son mesajları gönder
    messages = Message.list_by_room(room_id, 20)
    push(socket, "message_history", %{messages: messages})
    {:noreply, socket}
  end

  # PubSub'dan gelen mesajları client'a ilet
  def handle_info({event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("new_message", %{"content" => content} = params, socket) do
    room_id = get_room_id(socket)
    sender_id = Map.get(params, "sender_id", "anonymous")
    sender_name = Map.get(params, "sender_name", "Anonim")

    case Message.create(%{
           room_id: room_id,
           sender_id: sender_id,
           sender_name: sender_name,
           content: content,
           message_type: Map.get(params, "message_type", "text")
         }) do
      {:ok, message} ->
        broadcast!(socket, "new_message", %{
          id: message.id,
          sender_id: message.sender_id,
          sender_name: message.sender_name,
          content: message.content,
          timestamp: message.inserted_at
        })

        {:reply, :ok, %{id: message.id}, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Mesaj kaydedilemedi"}}, socket}
    end
  end

  def handle_in("agent_event", params, socket) do
    # Agent'lardan gelen MCP/A2A olayları — human topic'e yayınla
    broadcast!(socket, "agent_event", params)
    {:noreply, socket}
  end

  def handle_in(_event, _params, socket) do
    {:noreply, socket}
  end

  defp get_room_id(socket) do
    "room:" <> room_id = socket.topic
    room_id
  end
end
