import Config

# Çalışma zamanı konfigürasyonu — Ortam değişkenleriyle override
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise("DATABASE_URL ortam değişkeni tanımlı değil!")

  config :agentbot_core, LiteLLM.HTTPAdapter,
    base_url: System.get_env("LITELLM_BASE_URL") || "http://litellm:4000",
    master_key: System.get_env("LITELLM_MASTER_KEY")

  config :agentbot_core, LiteLLM, adapter: LiteLLM.HTTPAdapter
end
