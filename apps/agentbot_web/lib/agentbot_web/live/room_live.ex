defmodule AgentbotWeb.RoomLive do
  @moduledoc "Oda detay — canlı mesajlaşma"

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.{Room, Message}
  alias AgentbotCore.Repo

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    if connected?(socket) do
      AgentbotCore.PubSub.subscribe("room:#{room_id}")
      AgentbotCore.PubSub.subscribe("human:#{room_id}")
    end

    case Repo.get(Room, room_id) do
      nil ->
        {:ok, push_navigate(socket, to: "/rooms")}

      room ->
        messages = Message.list_by_room(room_id, 50)

        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:messages, messages)
         |> assign(:message_count, length(messages))}
    end
  end

  @impl true
  def handle_event("send_message", params, socket) do
    content = (params["content"] || "") |> String.trim()
    sender_name = params["sender_name"] || "İnsan"

    if content == "" do
      {:noreply, socket}
    else
      room = socket.assigns.room

      case Message.create(%{
             room_id: room.id,
             sender_id: "human-web",
             sender_name: sender_name,
             content: content,
             message_type: "text"
           }) do
        {:ok, _msg} ->
          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Gönderilemedi")}
      end
    end
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply,
     socket
     |> update(:messages, fn m -> [msg | m] end)
     |> update(:message_count, &(&1 + 1))}
  end

  def handle_info({event, payload}, socket) when event in [:agent_joined, :agent_left] do
    {:noreply, put_flash(socket, :info, format_agent_event(event, payload))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp format_agent_event(:agent_joined, %{agent_name: name}), do: "🤖 #{name} katıldı"
  defp format_agent_event(_, _), do: "Agent aktivitesi"

  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
