defmodule AgentbotCore.MixProject do
  use Mix.Project

  @moduledoc "AgentAndBot çekirdek kütüphanesi — Modüller, schema'lar ve iş mantığı"

  def project do
    [
      app: :agentbot_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {AgentbotCore.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.1"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      # Test/Lint — Anti-Crash Manifesto
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Anti-Crash Manifesto: quality gate alias
      quality: ["compile --warnings-as-errors", "credo --strict", "test"]
    ]
  end
end
