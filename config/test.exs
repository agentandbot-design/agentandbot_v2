import Config

# Test ortamı — sandbox modunda in-memory benzeri hızlı DB
config :agentbot_core, AgentbotCore.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST", "core-postgres"),
  database: "agentbot_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :agentbot_web, AgentbotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "WzX7kP2mQ8vR4nL6jF0hG3dY9sT5bC1aE8uI0oK7pM3xN6wV2jF4hD8gB5cA9eR",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_order, [:phoenix_pubsub]
