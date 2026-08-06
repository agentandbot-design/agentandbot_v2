import Config

# Test ortamı konfigürasyonu
config :agentbot_core, AgentbotCore.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "core-postgres",
  database: "agentbot_dev_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20

config :agentbot_web, AgentbotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

config :logger, level: :warning
