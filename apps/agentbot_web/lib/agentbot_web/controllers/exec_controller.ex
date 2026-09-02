defmodule AgentbotWeb.ExecController do
  @moduledoc """
  POST /api/exec — Web Terminal Protocol v1 (bkz. aab-terminal/PROTOCOL.md).

  Okuma komutları herkese açık; mutasyon komutları Bearer token ister.
  Token: AgentAndBot agent credential (AuthGate.verify_token).
  """

  import Plug.Conn

  alias AgentbotCore.Modules.Console.CommandEngine
  alias AgentbotCore.Modules.Security.AuthGate

  def init(opts), do: opts

  def call(conn, :exec) do
    case conn.body_params do
      %{"cmd" => cmd} when is_binary(cmd) and cmd != "" ->
        ctx = auth_context(conn)

        case CommandEngine.exec(cmd, ctx) do
          %{ok: true} = result ->
            json(conn, 200, result)

          %{code: :unauthorized} = result ->
            json(conn, 401, result)

          result ->
            json(conn, 200, result)
        end

      _ ->
        json(conn, 400, %{ok: false, code: "usage", output: "Gövde: {\"cmd\": \"...\"}"})
    end
  end

  def call(conn, :version) do
    json(conn, 200, %{protocol: 1})
  end

  defp auth_context(conn) do
    token = extract_token(conn)

    case token && AuthGate.verify_token(token) do
      {:ok, agent} ->
        %{agent_id: agent.agent_id, agent_name: agent.agent_name, user_id: agent.agent_id}

      _ ->
        %{}
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> String.trim(token)
      _ -> nil
    end
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
