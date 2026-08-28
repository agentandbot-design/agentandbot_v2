defmodule AgentbotCore.Modules.Memory.FusionSearch do
  @moduledoc """
  Mem0 (kişisel hafıza) + mem.agentandbot.com (kurumsal hafıza)
  birleşik arama — RRF (Reciprocal Rank Fusion) ile sonuçları birleştirir.

  Agent sorgu geldiğinde:
    1. Mem0'da user/agent bazlı hafıza ara.
    2. mem.agentandbot.com'da kurumsal bilgi ara.
    3. RRF ile birleştir, skorla sırala.

  Cerebras tarzı: Birden çok kaynaktan gelen sonuçlar tek bir skorla sıralanır.
  """

  require Logger

  alias AgentbotCore.Modules.Memory.MCPClient
  alias AgentbotCore.Modules.Memory.MemLocalClient

  @rrf_k 60
  @default_limit 10

  @type unified_result :: %{
          id: String.t(),
          content: String.t(),
          score: float(),
          source: :personal | :enterprise,
          metadata: map(),
          timestamp: String.t() | nil
        }

  @spec search(String.t(), String.t(), keyword()) :: {:ok, [unified_result()]} | {:error, term()}
  def search(query, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    # Paralel çağrılar (Mem0 + Mem)
    tasks = [
      Task.async(fn -> fetch_mem0_results(query, user_id) end),
      Task.async(fn -> fetch_mem_local_results(query) end)
    ]

    [mem0_res, mem_local_res] = Task.await_many(tasks, 30_000)

    # RRF fusion
    fused =
      []
      |> merge_results(mem0_res, :personal)
      |> merge_results(mem_local_res, :enterprise)
      |> rrf_fusion()
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)

    {:ok, fused}
  end

  # -----------------------------------------------------------------
  # Mem0 (kişisel) arama — hosted MCP server
  # -----------------------------------------------------------------
  defp fetch_mem0_results(query, user_id) do
    url = Application.get_env(:agentbot_core, :mem0_mcp_url) || "https://mcp.mem0.ai/mcp"
    key = mem0_key()

    # MCP tool call: search_memories
    case MCPClient.call_tool(url, key, "search_memories", %{
           "query" => query,
           "user_id" => user_id,
           "top_k" => 10
         }) do
      {:ok, %{"content" => content}} ->
        parse_mem0_content(content)

      {:ok, result} ->
        parse_mem0_content(result["content"] || [])

      {:error, reason} ->
        Logger.warning("Mem0 search failed: #{inspect(reason)}")
        []
    end
  end

  defp parse_mem0_content(content) when is_list(content) do
    Enum.flat_map(content, fn
      %{"text" => json_text} ->
        case Jason.decode(json_text) do
          {:ok, %{"results" => results}} when is_list(results) ->
            Enum.map(results, fn r ->
              %{
                id: r["id"] || Ecto.UUID.generate(),
                content: r["memory"],
                raw_score: r["score"] || 0.0,
                metadata: r["metadata"] || %{},
                timestamp: r["created_at"]
              }
            end)

          _ ->
            []
        end

      _ ->
        []
    end)
  end

  defp parse_mem0_content(_), do: []

  # -----------------------------------------------------------------
  # Mem (kurumsal) arama
  # -----------------------------------------------------------------
  defp fetch_mem_local_results(query) do
    case MemLocalClient.search(query) do
      {:ok, %{"results" => results}} when is_list(results) ->
        Enum.map(results, fn r ->
          %{
            id: to_string(r["id"]),
            content: r["content"],
            raw_score: r["score"],
            metadata: r["metadata"] || %{},
            timestamp: r["inserted_at"]
          }
        end)

      {:error, reason} ->
        Logger.warning("Mem local search failed: #{inspect(reason)}")
        []
    end
  end

  # -----------------------------------------------------------------
  # RRF Fusion
  # -----------------------------------------------------------------
  defp merge_results(acc, results, source_tag) do
    results
    |> Enum.with_index(1)
    |> Enum.map(fn {r, rank} ->
      Map.merge(r, %{
        source: source_tag,
        rank: rank,
        rrf_score: 1.0 / (@rrf_k + rank)
      })
    end)
    |> Enum.concat(acc)
  end

  defp rrf_fusion(results) do
    results
    |> Enum.group_by(& &1.id)
    |> Enum.map(fn {_id, group} ->
      best = hd(group)
      total_rrf = Enum.sum(Enum.map(group, & &1.rrf_score))

      %{
        id: best.id,
        content: best.content,
        score: Float.round(total_rrf, 6),
        source: best.source,
        metadata: best.metadata,
        timestamp: best.timestamp
      }
    end)
  end

  defp mem0_key do
    Application.get_env(:agentbot_core, :mem0_api_key) ||
      System.get_env("MEM0_API_KEY") ||
      raise("MEM0_API_KEY is not configured")
  end
end
