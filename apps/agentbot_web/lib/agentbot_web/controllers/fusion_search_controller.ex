defmodule AgentbotWeb.FusionSearchController do
  @moduledoc """
  Mem0 (kişisel hafıza) + mem.agentandbot.com (kurumsal hafıza) birleşik arama.

  `GET /api/fusion-search?q=...&user_id=...&limit=10`

  Auth: Bearer token (agentandbot.com AuthPlug). `memory.read` yetkisi
  AuthPlug tarafından kontrol edilir; burada agent kimliği sorgu için
  kullanılır.
  """

  import Plug.Conn

  alias AgentbotCore.Modules.Memory.FusionSearch

  def init(opts), do: opts

  def call(conn, :search) do
    q = conn.params["q"] || conn.query_params["q"] || ""
    user_id = conn.params["user_id"] || conn.assigns[:agent_id] || "anonymous"
    limit = int_param(conn, "limit", 10)

    if q == "" do
      send_json(conn, 400, %{error: "q parametresi gerekli"})
    else
      case FusionSearch.search(q, user_id, limit: limit) do
        {:ok, results} ->
          send_json(conn, 200, %{
            query: q,
            user_id: user_id,
            count: length(results),
            results: results
          })
      end
    end
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  defp int_param(conn, key, default) do
    case conn.query_params[key] do
      nil -> default
      val ->
        case Integer.parse(val) do
          {n, _} -> n
          :error -> default
        end
    end
  end
end
