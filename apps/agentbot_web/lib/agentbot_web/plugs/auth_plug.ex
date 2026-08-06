defmodule AgentbotWeb.Plugs.AuthPlug do
  @moduledoc """
  Authentication plug — her authenticated request'te token doğrular.

  Conn.assigns'a agent_id ve agent_info atar.
  """

  import Plug.Conn

  alias AgentbotCore.Modules.Security.AuthGate

  @doc false
  def init(opts), do: opts

  def call(conn, _opts) do
    case AuthGate.authenticate(conn) do
      {:ok, agent_info} ->
        conn
        |> assign(:agent_id, agent_info.agent_id)
        |> assign(:agent_info, agent_info)

      {:error, reason} ->
        conn
        |> put_status(401)
        |> halt()
        |> Phoenix.Controller.json(%{error: reason})
    end
  end
end
