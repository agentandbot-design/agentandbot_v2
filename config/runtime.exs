import Config

# Çalışma zamanı konfigürasyonu — Ortam değişkenleriyle override
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise("DATABASE_URL ortam değişkeni tanımlı değil!")

  config :agentbot_core, AgentbotCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "15")
end
