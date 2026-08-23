defmodule AgentbotWeb.Layouts do
  @moduledoc "Uygulama layout'ları"

  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]

  use Phoenix.VerifiedRoutes,
    endpoint: AgentbotWeb.Endpoint,
    router: AgentbotWeb.Router,
    statics: ~w(assets fonts images favicon.ico robots.txt)

  embed_templates("layouts/*")
end
