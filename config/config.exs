import Config

# Genel konfigürasyon — tüm ortamlar için temel ayarlar
config :agentbot_core,
  ecto_repos: [AgentbotCore.Repo]

config :agentbot_web,
  generators: [timestamp_type: :utc_datetime]

# Phoenix endpoint konfigürasyonu
config :agentbot_web, AgentbotWeb.Endpoint,
  url: [host: "localhost", port: 4000],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: "WzX7kP2mQ8vR4nL6jF0hG3dY9sT5bC1aE8uI0oK7pM3xN6wV2jF4hD8gB5cA9eR",
  render_errors: [view: AgentbotWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: AgentbotWeb.PubSub,
  live_view: [signing_salt: "aB3cD4eF5gH6iJ7kL8mN"]

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import ortam bazlı konfigürasyon
import_config "#{config_env()}.exs"
