defmodule AgentbotWeb.UserSocket do
  @moduledoc """
  Phoenix WebSocket socket — agent ve insan bağlantıları için.

  Route: ws://host:4000/socket/websocket
  Channel: room:lobby → AgentbotWeb.RoomChannel
  """

  use Phoenix.Socket

  channel "room:*", AgentbotWeb.RoomChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
