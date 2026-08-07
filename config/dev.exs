import Config

# Geliştirme ortamı konfigürasyonu
config :agentbot_core, AgentbotCore.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "core-postgres",
  database: "agentbot_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :agentbot_web, AgentbotWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# Geliştirme modunda log seviyesi debug
config :logger, level: :debug

config :phoenix, :plug_init_order, [:phoenix_pubsub, :phoenix_live_reload]
