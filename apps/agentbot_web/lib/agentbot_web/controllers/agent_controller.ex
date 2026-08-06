defmodule AgentbotWeb.AgentController do
  @moduledoc "Ajan endpoint'leri — bağlantı ve iletişim"

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Agents.AgentGateway

  def connect(conn, params) do
    case AgentGateway.connect(params) do
      {:ok, result} ->
        conn |> put_status(201) |> json(result)
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end

  def disconnect(conn, _params) do
    agent_id = conn.assigns.agent_id
    AgentGateway.disconnect(agent_id)
    json(conn, %{status: "disconnected"})
  end
end
