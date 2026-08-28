defmodule AgentbotWeb.Router do
  @moduledoc """
  Ana router — tüm HTTP endpoint'leri tanımlanır.

  WellKnown discovery, health check, ve API endpoint'leri.
  """

  use AgentbotWeb, :router

  # Sağlık kontrolü — authentication gerektirmez
  get("/health", AgentbotWeb.HealthController, :index)

  # WellKnown discovery endpoint'leri
  get("/.agent-well-known/skill", AgentbotWeb.WellKnownController, :skill)
  get("/.agent-well-known/agent.json", AgentbotWeb.WellKnownController, :agent)
  get("/.agent-well-known/protocols", AgentbotWeb.WellKnownController, :protocols)

  # API Pipeline — token doğrulama gerekli
  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :authenticated do
    plug(:accepts, ["json"])
    plug(AgentbotWeb.Plugs.AuthPlug)
  end

  # Ajan gateway endpoint'leri
  scope "/api" do
    pipe_through(:authenticated)

    post("/agents/connect", AgentbotWeb.AgentController, :connect)
    post("/agents/disconnect", AgentbotWeb.AgentController, :disconnect)
    post("/envelope", AgentbotWeb.EnvelopeController, :send)
  end

  # Ana API rehberi — auth yok
  get("/api", AgentbotWeb.ApiGuideController, :index)

  # Genel API
  scope "/api" do
    pipe_through(:api)

    get("/rooms", AgentbotWeb.RoomController, :index)
    post("/rooms", AgentbotWeb.RoomController, :create)
    get("/rooms/:id/messages", AgentbotWeb.RoomController, :messages)
    get("/rooms/:id/messages/since/:last_id", AgentbotWeb.RoomController, :messages_since)
    get("/agents/online", AgentbotWeb.AgentController, :online)

    # Resource Marketplace — CPU, RAM, GPU, API
    get("/resources", AgentbotWeb.ResourceController, :index)
    get("/resources/:type", AgentbotWeb.ResourceController, :by_type)

    # MCP Registry — merkezi MCP sunucu keşfi
    get("/mcp-servers", AgentbotWeb.McpRegistryController, :index)
    get("/mcp-servers/:name", AgentbotWeb.McpRegistryController, :show)
    get("/mcp-servers/search/:tag", AgentbotWeb.McpRegistryController, :search)

    # Council — konsey: soru → N agent → görüşler
    get("/councils", AgentbotWeb.CouncilController, :index)
    get("/council/:id", AgentbotWeb.CouncilController, :show)

    # Task API — Discover → Delegate → Verify
    get("/tasks", AgentbotWeb.TaskController, :index)
    get("/tasks/:id", AgentbotWeb.TaskController, :show)

    # Human entry — auth yok, insan da gelir derdini soyler
    post("/request", AgentbotWeb.TaskController, :human_request)

    # Capability Registry — L1
    get("/capabilities", AgentbotWeb.CapabilityController, :index)
    get("/capabilities/:name", AgentbotWeb.CapabilityController, :show)
    get("/discover", AgentbotWeb.CapabilityController, :discover)
    get("/gaps/top", AgentbotWeb.CapabilityController, :top_gaps)

    # Ecosystem Catalog — ajan ekosistemi takip kataloğu
    get("/ecosystem", AgentbotWeb.EcosystemController, :index)
    get("/ecosystem/categories", AgentbotWeb.EcosystemController, :categories)
    post("/ecosystem", AgentbotWeb.EcosystemController, :create)
    get("/gaps", AgentbotWeb.CapabilityController, :unfulfilled_gaps)

    # Provisioning API — gap→recipe→deploy→verify döngüsü (public view)
    get("/gaps/:id/recipes", AgentbotWeb.ProvisioningController, :index_gap_recipes)
    get("/recipes/:id", AgentbotWeb.ProvisioningController, :show_recipe)
    get("/deployments/:id", AgentbotWeb.ProvisioningController, :show_deployment)
  end

  # Authenticated API — agent işlemleri
  scope "/api" do
    pipe_through(:authenticated)

    post("/tasks", AgentbotWeb.TaskController, :create)
    post("/tasks/:task_id/assign", AgentbotWeb.TaskController, :assign)
    post("/tasks/:task_id/claim", AgentbotWeb.TaskController, :claim)
    post("/tasks/:task_id/status", AgentbotWeb.TaskController, :update_status)
    post("/tasks/:task_id/artifact", AgentbotWeb.TaskController, :submit_artifact)
    post("/artifacts/:id/verify", AgentbotWeb.TaskController, :verify_artifact)

    # MCP Registry — kayıt ve yönetim (auth gerekir)
    post("/mcp-servers/register", AgentbotWeb.McpRegistryController, :register)
    put("/mcp-servers/:name", AgentbotWeb.McpRegistryController, :update)
    delete("/mcp-servers/:name", AgentbotWeb.McpRegistryController, :delete)

    # Agent provides capability
    post("/capabilities/provide", AgentbotWeb.CapabilityController, :provide)

    # Agent provides resources (CPU, RAM, GPU, API)
    post("/resources/provide", AgentbotWeb.ResourceController, :provide)

    # Council — konsey (public create, auth respond)
    post("/council", AgentbotWeb.CouncilController, :create)
    post("/council/:id/respond", AgentbotWeb.CouncilController, :respond)
    post("/council/:id/synthesize", AgentbotWeb.CouncilController, :synthesize)

    # Provisioning API — deployment register + verify (auth required)
    post("/deployments", AgentbotWeb.ProvisioningController, :create_deployment)
    post("/deployments/:id/verify", AgentbotWeb.ProvisioningController, :verify_deployment)

    # Fusion Search — Mem0 (kişisel) + mem.agentandbot.com (kurumsal) birleşik arama
    get("/fusion-search", AgentbotWeb.FusionSearchController, :search)
  end

  # Agent registration — token üretir (auth yok)
  scope "/api" do
    pipe_through(:api)

    post("/agents/register", AgentbotWeb.AgentController, :register)
  end

  # HTTP POST mesaj gönderme (LiveView fallback)
  post("/rooms/:room_id/messages", AgentbotWeb.RoomController, :create_message)

  # LiveView — Browser UI
  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AgentbotWeb.Layouts, :root})
    plug(:protect_from_forgery)
  end

  scope "/", AgentbotWeb do
    pipe_through(:browser)

    live("/", DashboardLive, :index)
    live("/platform", PlatformLive, :index)
    live("/ecosystem", EcosystemLive, :index)
    live("/rooms", RoomListLive, :index)
    live("/rooms/:id", RoomLive, :show)
    live("/gaps", GapsLive, :index)
    live("/recipes", RecipesLive, :index)
    live("/deployments", DeploymentsLive, :index)
  end

  # 404 yakalayıcı
  match(:*, "/*path", AgentbotWeb.ErrorController, :not_found)
end
