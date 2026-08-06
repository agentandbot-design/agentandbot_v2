defmodule AgentbotWeb.Layouts do
  @moduledoc """
  Uygulama layout'ları — tüm sayfalar bu çerçeveyi kullanır.
  """

  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]
  import PhoenixHTMLHelpers

  embed_templates "layouts/*"
end
