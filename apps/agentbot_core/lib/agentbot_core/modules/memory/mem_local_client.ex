defmodule AgentbotCore.Modules.Memory.MemLocalClient do
  @moduledoc """
  mem.agentandbot.com — kurumsal hafiza istemcisi.

  API:
    POST /api/memory       → ingest
    GET  /api/memory/search?q=...&limit=...&source=...&project=... → hybrid search
    GET  /health           → service health
  """

  alias AgentbotCore.Modules.Memory.Mem0Result

  @base_url "https://mem.agentandbot.com"
  @timeout 20_000

  @spec ingest(map()) :: Mem0Result.t()
  def ingest(chunk) when is_map(chunk) do
    request("/api/memory", :post, chunk)
  end

  @spec search(String.t(), keyword()) :: Mem0Result.t()
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    source = Keyword.get(opts, :source)
    project = Keyword.get(opts, :project)

    params =
      [{"q", query}, {"limit", to_string(limit)}]
      |> add_param("source", source)
      |> add_param("project", project)

    request("/api/memory/search?" <> URI.encode_query(params), :get, nil)
  end

  @spec health() :: Mem0Result.t()
  def health do
    request("/health", :get, nil)
  end

  # -----------------------------------------------------------------
  # Internals
  # -----------------------------------------------------------------
  defp add_param(list, _key, nil), do: list
  defp add_param(list, key, value), do: [{key, value} | list]

  defp request(path, method, payload) do
    url = @base_url <> "/" <> path
    headers = [{"Authorization", "Bearer #{api_key()}"}]

    req =
      case method do
        :get ->
          Req.new(method: :get, url: url, headers: headers, receive_timeout: @timeout)

        :post ->
          Req.new(
            method: :post,
            url: url,
            headers: [{"Content-Type", "application/json"} | headers],
            json: payload,
            receive_timeout: @timeout
          )
      end

    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key do
    Application.get_env(:agentbot_core, :mem_local_api_key) ||
      System.get_env("MEM_LOCAL_API_KEY") ||
      System.get_env("MEM_TOKEN") ||
      raise("MEM_LOCAL_API_KEY or MEM_TOKEN env must be set")
  end
end
