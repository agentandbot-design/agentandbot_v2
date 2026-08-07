defmodule AgentbotWeb.MixProject do
  use Mix.Project

  @moduledoc "AgentAndBot web arayüzü — Phoenix REST API ve LiveView"

  def project do
    [
      app: :agentbot_web,
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
      mod: {AgentbotWeb.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:agentbot_core, in_umbrella: true},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:gettext, "~> 0.26"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      # Asset pipeline
      {:esbuild, "~> 0.8", runtime: false},
      {:tailwind, "~> 0.2", runtime: false},
      {:heroicons, "~> 0.5"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify"]
    ]
  end
end
