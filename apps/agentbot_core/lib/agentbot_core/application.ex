defmodule AgentbotCore.Application do
  @moduledoc """
  AgentbotCore OTP uygulaması.

  Repo, PubSub ve süpervizör ağacını başlatır.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Veritabanı repository'si
      AgentbotCore.Repo,
      # PubSub — gerçek zamanlı mesajlaşma için
      {Phoenix.PubSub, name: AgentbotCore.PubSub},
      # Oda süreç kayıt defteri
      {Registry, keys: :unique, name: AgentbotCore.Modules.Chat.RoomRegistry},
      # Agent presence tracker — ETS tabanlı çevrimiçi takibi
      AgentbotCore.Modules.Agents.AgentPresence,
      # Oda dinamik süpervizörü — her oda için bir RoomServer başlatır
      AgentbotCore.Modules.Chat.RoomSupervisor
    ]

    opts = [strategy: :one_for_one, name: AgentbotCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
