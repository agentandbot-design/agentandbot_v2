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

  # Agent registration — token üretir (auth yok)
  scope "/api" do
    pipe_through :api

    post "/agents/register", AgentbotWeb.AgentController, :register
  end

  # HTTP POST mesaj gönderme (LiveView fallback)
  post "/rooms/:room_id/messages", AgentbotWeb.RoomController, :create_message

  # LiveView — Browser UI
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AgentbotWeb.Layouts, :root}
    plug :protect_from_forgery
  end

  scope "/", AgentbotWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/rooms", RoomListLive, :index
    live "/rooms/:id", RoomLive, :show
  end

  # 404 yakalayıcı
  match :*, "/*path", AgentbotWeb.ErrorController, :not_found
end
