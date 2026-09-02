import Config

# Çalışma zamanı konfigürasyonu — Ortam değişkenleriyle override
if config_env() == :prod do
  # Prod boot'ta DATABASE_URL varlık doğrulaması (bağlantı prod.exs'te DB_* ile kurulur)
  _database_url =
    System.get_env("DATABASE_URL") ||
      raise("DATABASE_URL ortam değişkeni tanımlı değil!")

  config :agentbot_core, LiteLLM.HTTPAdapter,
    base_url: System.get_env("LITELLM_BASE_URL") || "http://litellm:4000",
    master_key: System.get_env("LITELLM_MASTER_KEY")

  config :agentbot_core, LiteLLM, adapter: LiteLLM.HTTPAdapter

  # Memory layer configuration
  config :agentbot_core,
         :mem_local_api_key,
         System.get_env("MEM_LOCAL_API_KEY") || System.get_env("MEM_TOKEN")

  config :agentbot_core, :mem0_api_key, System.get_env("MEM0_API_KEY")

  config :agentbot_core,
         :mem0_mcp_url,
         System.get_env("MEM0_MCP_URL") || "https://mcp.mem0.ai/mcp"
end
