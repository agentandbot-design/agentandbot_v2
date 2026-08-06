defmodule AgentbotUmbrella.MixProject do
  use Mix.Project

  # Umbrella root — alt uygulamaları yönetir
  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp deps do
    [
      # Phoenix ve bağımlılıkları
      {:phoenix, "~> 1.8.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
