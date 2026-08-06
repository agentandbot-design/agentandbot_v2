defmodule AgentbotWeb do
  @moduledoc """
  AgentAndBot web arayüzü — Phoenix REST API.
  """

  def controller do
    quote do
      use Phoenix.Controller, formats: [json: AgentbotWeb.ErrorView]
      import Plug.Conn
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
