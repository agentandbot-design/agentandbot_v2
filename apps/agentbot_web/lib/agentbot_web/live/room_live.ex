defmodule AgentbotWeb.RoomLive do
  @moduledoc """
  Oda detay sayfası — canlı mesajlaşma, agent aktivitesi.

  PubSub'a abone olur, yeni mesajları anında gösterir.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.{Room, Message}

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    if connected?(socket) do
      AgentbotCore.PubSub.subscribe("room:#{room_id}")
      AgentbotCore.PubSub.subscribe("human:#{room_id}")
    end

    case Room |> AgentbotCore.Repo.get(room_id) do
      nil ->
        {:ok, put_flash(socket, :error, "Oda bulunamadı") |> push_navigate(to: "/rooms")}

      room ->
        messages = Message.list_by_room(room_id, 50)

        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:messages, messages)
         |> assign(:message_count, length(messages))
         |> assign(:form, to_form(%{"content" => "", "sender_name" => "İnsan"}))}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content, "sender_name" => sender_name}, socket) do
    room = socket.assigns.room

    case Message.create(%{
           room_id: room.id,
           sender_id: "human-web",
           sender_name: sender_name,
           content: content,
           message_type: "text"
         }) do
      {:ok, _msg} ->
        {:noreply, assign(socket, :form, to_form(%{"content" => "", "sender_name" => sender_name}))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Mesaj gönderilemedi")}
    end
  end

  def handle_event("maybe-send", %{"key" => "Enter", "shiftKey" => false}, socket) do
    {:noreply, socket}
  end

  def handle_event("maybe-send", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply,
     socket
     |> update(:messages, fn msgs -> [msg | msgs] end)
     |> update(:message_count, &(&1 + 1))
     |> push_event("new_message", %{})}
  end

  def handle_info({event, payload}, socket) when event in [:agent_joined, :agent_left] do
    {:noreply, put_flash(socket, :info, format_agent_event(event, payload))}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp format_agent_event(:agent_joined, %{agent_name: name}),
    do: "🤖 #{name} odaya katıldı"

  defp format_agent_event(:agent_left, %{agent_id: id}),
    do: "🤖 Agent #{id} odadan ayrıldı"

  defp format_agent_event(_, _), do: "Agent aktivitesi"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
