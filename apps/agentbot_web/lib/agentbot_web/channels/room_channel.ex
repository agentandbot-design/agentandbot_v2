defmodule AgentbotWeb.RoomChannel do
  @moduledoc "Oda WebSocket kanalı — gerçek zamanlı mesajlaşma"

  use Phoenix.Channel

  def join("room:" <> _room_id, _params, socket) do
    {:ok, socket}
  end

  def handle_in("new_message", params, socket) do
    broadcast!(socket, "new_message", params)
    {:noreply, socket}
  end
end
