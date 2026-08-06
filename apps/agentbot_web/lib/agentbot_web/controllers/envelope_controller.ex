defmodule AgentbotWeb.EnvelopeController do
  @moduledoc "Envelope endpoint'leri — mesaj zarfı gönderme"

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Agents.AgentGateway

  def send(conn, params) do
    agent_id = conn.assigns.agent_id
    agent_info = conn.assigns.agent_info

    case AgentGateway.send_envelope(agent_id, params, agent_info) do
      {:ok, envelope_id} ->
        conn |> put_status(202) |> json(%{envelope_id: envelope_id, status: "sent"})

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end
end
