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
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

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
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
