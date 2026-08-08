defmodule AgentbotWeb.UserSocket do
  @moduledoc """
  Phoenix WebSocket socket — agent ve insan bağlantıları için.

  Route: ws://host:4000/socket/websocket?token=***

  Channels:
    - room:* → RoomChannel (mesajlaşma)
    - agent:* → AgentChannel (council/task push notification — polling yok)
  """

  use Phoenix.Socket

  channel "room:*", AgentbotWeb.RoomChannel
  channel "agent:*", AgentbotWeb.AgentChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    alias AgentbotCore.Modules.Security.AuthGate

    case AuthGate.verify_token(token) do
      {:ok, agent_info} ->
        {:ok,
         socket
         |> assign(:agent_id, agent_info.agent_id)
         |> assign(:agent_name, agent_info.agent_name)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, socket, _connect_info) do
    # Token yok — sadece room channel'e izin ver (anonymous)
    {:ok, socket}
  end

  @impl true
  def id(socket) do
    if socket.assigns[:agent_id] do
      "agent_socket:#{socket.assigns.agent_id}"
    else
      nil
    end
  end
end
