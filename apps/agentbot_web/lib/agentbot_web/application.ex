defmodule AgentbotWeb.Application do
  @moduledoc """
  AgentbotWeb OTP uygulaması — HTTP sunucu ve endpoint.

  AgentbotCore'den bağımsız olarak başlatılır, ama
  çekirdek modüllerin süreçlerine bağımlıdır.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # PubSub — web layer için
      {Phoenix.PubSub, name: AgentbotWeb.PubSub},
      # HTTP endpoint
      AgentbotWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AgentbotWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AgentbotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
