defmodule AgentbotWeb.Router do
  @moduledoc """
  Ana router — tüm HTTP endpoint'leri tanımlanır.

  WellKnown discovery, health check, ve API endpoint'leri.
  """

  use AgentbotWeb, :router

  # Sağlık kontrolü — authentication gerektirmez
  get "/health", AgentbotWeb.HealthController, :index

  # WellKnown discovery endpoint'leri
  get "/.agent-well-known/skill", AgentbotWeb.WellKnownController, :skill
  get "/.agent-well-known/agent.json", AgentbotWeb.WellKnownController, :agent
  get "/.agent-well-known/protocols", AgentbotWeb.WellKnownController, :protocols

  # API Pipeline — token doğrulama gerekli
  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug :accepts, ["json"]
    plug AgentbotWeb.Plugs.AuthPlug
  end

  # Ajan gateway endpoint'leri
  scope "/api" do
    pipe_through :authenticated

    post "/agents/connect", AgentbotWeb.AgentController, :connect
    post "/agents/disconnect", AgentbotWeb.AgentController, :disconnect
    post "/envelope", AgentbotWeb.EnvelopeController, :send
  end

  # Genel API
  scope "/api" do
    pipe_through :api

    get "/rooms", AgentbotWeb.RoomController, :index
    post "/rooms", AgentbotWeb.RoomController, :create
    get "/rooms/:id/messages", AgentbotWeb.RoomController, :messages
  end

  # 404 yakalayıcı
  match :*, "/*path", AgentbotWeb.ErrorController, :not_found
end
