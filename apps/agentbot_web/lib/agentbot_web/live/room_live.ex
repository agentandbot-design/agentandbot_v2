defmodule AgentbotWeb.RoomLive do
  @moduledoc """
  Oda detay — canlı mesajlaşma, agent presence, approval paneli.

  Özellikler:
  - Mesaj akışı (agent/human ayrımı)
  - Çevrimiçi agent sidebar'ı (gerçek zamanlı)
  - Onay talebi paneli (approve/reject)
  - Oda duraklatma/devam ettirme
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Agents.AgentPresence
  alias AgentbotCore.Modules.Chat.ApprovalRequest
  alias AgentbotCore.Modules.Chat.Message
  alias AgentbotCore.Modules.Chat.Room
  alias AgentbotCore.Modules.Chat.RoomServer
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
        room_id_str = Integer.to_string(room.id)
        messages = Message.list_by_room(room.id, 50)
        approvals = ApprovalRequest.list_pending_by_room(room.id)
        room_state = get_room_state(room.id)
        online_agents = AgentPresence.list_in_room(room_id_str)

        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:room_id_str, room_id_str)
         |> assign(:message_count, length(messages))
         |> assign(:sender_name, "İnsan")
         |> assign(:form, to_form(%{}))
         |> assign(:approvals, approvals)
         |> assign(:room_status, room_state[:status] || :active)
         |> assign(:online_agents, online_agents)
         |> stream(:messages, messages)}
    end
  end

  # ── Mesaj Gönderme ──────────────────────────────────────────────

  @impl true
  def handle_event("set_sender_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :sender_name, name)}
  end

  def handle_event("set_sender_name", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", params, socket) do
    content = String.trim(params["content"] || "")
    sender_name = params["sender_name"] || "İnsan"

    if content == "" do
      {:noreply, socket}
    else
      room = socket.assigns.room

      {:ok, _msg} =
        Message.create(%{
          room_id: room.id,
          sender_id: "human-web",
          sender_name: sender_name,
          content: content,
          message_type: "text"
        })

      {:noreply,
       socket
       |> assign(:form, to_form(%{}))
       |> assign(:sender_name, sender_name)}
    end
  end

  # ── Approval Events ─────────────────────────────────────────────

  def handle_event("approve", %{"id" => id}, socket) do
    ApprovalRequest.approve(id, "human-web")

    {:noreply,
     socket
     |> assign(:approvals, ApprovalRequest.list_pending_by_room(socket.assigns.room.id))
     |> put_flash(:info, "✅ Onaylandı")}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    ApprovalRequest.reject(id, "human-web")

    {:noreply,
     socket
     |> assign(:approvals, ApprovalRequest.list_pending_by_room(socket.assigns.room.id))
     |> put_flash(:warning, "❌ Reddedildi")}
  end

  # ── Room Control Events ─────────────────────────────────────────

  def handle_event("pause_room", _params, socket) do
    room_id_str = socket.assigns.room_id_str

    try do
      RoomServer.pause(room_id_str)
      {:noreply, assign(socket, :room_status, :paused)}
    catch
      :exit, _ ->
        {:noreply, put_flash(socket, :error, "Oda süreci bulunamadı")}
    end
  end

  def handle_event("resume_room", _params, socket) do
    room_id_str = socket.assigns.room_id_str

    try do
      RoomServer.resume(room_id_str)
      {:noreply, assign(socket, :room_status, :active)}
    catch
      :exit, _ ->
        {:noreply, put_flash(socket, :error, "Oda süreci bulunamadı")}
    end
  end

  # ── PubSub Handlers ─────────────────────────────────────────────

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply,
     socket
     |> stream_insert(:messages, msg, at: 0)
     |> update(:message_count, &(&1 + 1))}
  end

  def handle_info({:presence_update, %{event: event, agent_name: name}}, socket)
      when event == "joined" do
    online_agents = AgentPresence.list_in_room(socket.assigns.room_id_str)

    {:noreply,
     socket |> assign(:online_agents, online_agents) |> put_flash(:info, "🤖 #{name} katıldı")}
  end

  def handle_info({:presence_update, %{event: event}}, socket) when event == "left" do
    online_agents = AgentPresence.list_in_room(socket.assigns.room_id_str)
    {:noreply, assign(socket, :online_agents, online_agents)}
  end

  def handle_info({:room_paused, _payload}, socket) do
    {:noreply, assign(socket, :room_status, :paused)}
  end

  def handle_info({:room_resumed, _payload}, socket) do
    {:noreply, assign(socket, :room_status, :active)}
  end

  def handle_info({event, _payload}, socket) when event in [:agent_joined, :agent_left] do
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # ── Helpers ─────────────────────────────────────────────────────

  defp get_room_state(room_id) do
    room_id_str = Integer.to_string(room_id)

    try do
      RoomServer.get_state(room_id_str)
    catch
      :exit, _ -> %{status: :active}
    end
  end

  @doc "Mesaj tipini belirler — :agent, :human, :system"
  def msg_type(msg) do
    sender_id = msg.sender_id || ""

    cond do
      msg.message_type == "system" -> :system
      sender_id == "human-web" -> :human
      sender_id == "human" -> :human
      sender_id == "" -> :human
      true -> :agent
    end
  end

  @doc "Zaman formatla — bugün saat, değilse tarih + saat"
  def format_time(datetime) do
    today = Date.utc_today()
    date = DateTime.to_date(datetime)

    if Date.compare(date, today) == :eq do
      Calendar.strftime(datetime, "%H:%M")
    else
      Calendar.strftime(datetime, "%d.%m %H:%M")
    end
  end
end
