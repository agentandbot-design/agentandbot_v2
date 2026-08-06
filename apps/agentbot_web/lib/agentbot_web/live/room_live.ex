defmodule AgentbotWeb.RoomLive do
  @moduledoc """
  Oda detay sayfası — canlı mesajlaşma.
  """

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
         |> assign(:message_count, length(messages))
         |> assign(:sender_name, "İnsan")}
    end
  end

  # Enter tuşu ile veya buton ile mesaj gönder
  @impl true
  def handle_event("send", params, socket) do
    content =
      params["value"] || params["content"] || ""
      |> to_string()
      |> String.trim()

    sender_name = params["sender_name"] || socket.assigns.sender_name

    if content == "" do
      {:noreply, socket}
    else
      do_send_message(socket, content, sender_name)
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply,
     socket
     |> update(:messages, fn m -> [msg | m] end)
     |> update(:message_count, &(&1 + 1))
     |> push_event("msg_sent", %{})}
  end

  def handle_info({event, payload}, socket) when event in [:agent_joined, :agent_left] do
    {:noreply, put_flash(socket, :info, format_agent_event(event, payload))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp do_send_message(socket, content, sender_name) do
    room = socket.assigns.room

    case Message.create(%{
           room_id: room.id,
           sender_id: "human-web",
           sender_name: sender_name,
           content: content,
           message_type: "text"
         }) do
      {:ok, _msg} ->
        {:noreply,
         socket
         |> assign(:sender_name, sender_name)
         |> push_event("msg_sent", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Mesaj gönderilemedi")}
    end
  end

  defp format_agent_event(:agent_joined, %{agent_name: name}), do: "🤖 #{name} katıldı"
  defp format_agent_event(:agent_left, %{agent_id: id}), do: "🤖 #{id} ayrıldı"
  defp format_agent_event(_, _), do: "Agent aktivitesi"

  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
