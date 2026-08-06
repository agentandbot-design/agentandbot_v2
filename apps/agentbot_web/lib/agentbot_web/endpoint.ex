defmodule AgentbotWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint — HTTP isteklerini karşılar.
  """

  use Phoenix.Endpoint, otp_app: :agentbot_web

  # WebSocket / LiveView socket
  socket "/socket", AgentbotWeb.UserSocket,
    websocket: [path: "/ws"],
    longpoll: false

  # Plug pipeline
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session,
    store: :cookie,
    key: "_agentbot_web_key",
    signing_salt: "xK9mN2pL"

  plug AgentbotWeb.Router
end
