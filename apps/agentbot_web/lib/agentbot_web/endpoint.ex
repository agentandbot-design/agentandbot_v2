defmodule AgentbotWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint — HTTP isteklerini karşılar.
  """

  use Phoenix.Endpoint, otp_app: :agentbot_web

  @session_options [
    store: :cookie,
    key: "_agentbot_web_key",
    signing_salt: "xK9mN2pL"
  ]

  # WebSocket / LiveView socket
  socket "/socket", AgentbotWeb.UserSocket,
    websocket: [path: "/ws"],
    longpoll: false

  # LiveView socket
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # Plug pipeline
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Statik dosyalar — CSS, JS, favicon
  plug Plug.Static,
    at: "/",
    from: :agentbot_web,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug AgentbotWeb.Router
end
