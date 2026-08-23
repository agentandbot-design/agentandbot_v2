defmodule AgentbotWeb.AgentController do
  @moduledoc "Ajan endpoint'leri — kayıt, bağlantı ve iletişim"

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Agents.AgentGateway
  alias AgentbotCore.Modules.Agents.AgentPresence
  alias AgentbotCore.Modules.Security.AgentCredential

  @doc "Yeni agent kaydı — token üretir (auth gerektirmez)"
  def register(conn, params) do
    agent_id = Map.get(params, "agent_id")
    agent_name = Map.get(params, "agent_name")
    capabilities = Map.get(params, "capabilities", ["send_message"])
    executor_type = Map.get(params, "executor_type", "agent")
    endpoint = Map.get(params, "endpoint")

    cond do
      not is_binary(agent_id) or agent_id == "" ->
        conn |> put_status(400) |> json(%{error: "agent_id zorunlu"})

      not is_binary(agent_name) or agent_name == "" ->
        conn |> put_status(400) |> json(%{error: "agent_name zorunlu"})

      true ->
        case AgentCredential.register(%{
               agent_id: agent_id,
               agent_name: agent_name,
               capabilities: capabilities,
               executor_type: executor_type,
               endpoint: endpoint,
               description: Map.get(params, "description"),
               protocols: Map.get(params, "protocols", ["rest"])
             }) do
          {:ok, credential} ->
            conn
            |> put_status(201)
            |> json(%{
              agent_id: credential.agent_id,
              agent_name: credential.agent_name,
              token: credential.plain_token,
              capabilities: credential.capabilities,
              message: "Token'ı güvenle sakla — bir daha gösterilmeyecek"
            })

          {:error, _changeset} ->
            conn |> put_status(409) |> json(%{error: "Bu agent_id zaten kayıtlı olabilir"})
        end
    end
  end

  def connect(conn, params) do
    case AgentGateway.connect(params) do
      {:ok, result} ->
        conn |> put_status(201) |> json(result)

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end

  @doc "Çevrimiçi agent'ları listeler"
  def online(conn, _params) do
    agents = AgentPresence.list_online()
    json(conn, %{agents: agents, count: length(agents)})
  end

  def disconnect(conn, _params) do
    agent_id = conn.assigns.agent_id
    AgentGateway.disconnect(agent_id)
    json(conn, %{status: "disconnected"})
  end
end
