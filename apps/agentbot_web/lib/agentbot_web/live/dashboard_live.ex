defmodule AgentbotWeb.DashboardLive do
  @moduledoc """
  Dashboard — platform genel durumu.

  Oda sayısı, mesaj sayısı, agent durumu, son aktiviteler.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.{Room, Message}
  alias AgentbotCore.Repo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AgentbotCore.PubSub.subscribe("rooms")
      AgentbotCore.PubSub.subscribe("presence")
      :timer.send_interval(5000, :tick)
    end

    {:ok,
     socket
     |> assign_stats()
     |> assign(:recent_activity, [])}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign_stats(socket)}
  end

  def handle_info({:room_created, room}, socket) do
    activity = %{type: "room", text: "Yeni oda: #{room.name}", time: now_str()}

    new_activity =
      [activity | socket.assigns.recent_activity]
      |> Enum.take(10)

    {:noreply,
     socket
     |> assign_stats()
     |> assign(:recent_activity, new_activity)}
  end

  def handle_info({:agent_online, %{agent_name: name}}, socket) do
    activity = %{type: "agent", text: "🤖 #{name} çevrimiçi oldu", time: now_str()}

    new_activity =
      [activity | socket.assigns.recent_activity]
      |> Enum.take(10)

    {:noreply,
     socket
     |> assign_stats()
     |> assign(:recent_activity, new_activity)}
  end

  def handle_info({:agent_offline, _}, socket) do
    {:noreply, assign_stats(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_stats(socket) do
    socket
    |> assign(:room_count, count_rooms())
    |> assign(:message_count, count_messages())
    |> assign(:agent_count, count_agents())
    |> assign(:protocols, list_protocols())
  end

  defp count_rooms do
    Repo.aggregate(Room, :count)
  end

  defp count_messages do
    Repo.aggregate(Message, :count)
  end

  defp count_agents do
    # Phase 1: agent kayıt sayısı ( aktif token)
    Repo.aggregate(AgentbotCore.Modules.Security.AgentCredential, :count)
  end

  defp list_protocols do
    AgentbotCore.Modules.Protocol.ProtocolCatalog.protocols()
  end

  defp now_str do
    Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
  end
end
