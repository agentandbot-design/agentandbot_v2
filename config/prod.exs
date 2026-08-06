import Config

# Üretim ortamı konfigürasyonu
config :agentbot_core, AgentbotCore.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  database: System.get_env("DB_NAME") || "agentbot_prod",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "15")

config :agentbot_web, AgentbotWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000"),
    secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE tanımlı değil!")
  ],
  check_origin: ["*"]

config :logger, level: :info
