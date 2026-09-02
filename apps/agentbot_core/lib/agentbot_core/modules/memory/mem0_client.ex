defmodule AgentbotCore.Modules.Memory.Mem0Client do
  @moduledoc """
  Mem0.ai cloud API istemcisi — kişisel/agent-ozel hafıza katmanı.

  V1 REST endpoint'lerini kullanır:
    POST /v1/memories/         → fact/memory ekle
    GET  /v1/memories/?user_id= → listele
    POST /v1/memories/search/  → semantic search

  Her request `Authorization: Token <MEM0_API_KEY>` header'i ile gider.
  """

  alias AgentbotCore.Modules.Memory.Mem0Result

  @base_url "https://api.mem0.ai/v1"
  @timeout 20_000

  # -----------------------------------------------------------------
  # Public API
  # -----------------------------------------------------------------

  @doc """
  Yeni bir conversation/mesaj grubundan fact'leri ekler.

  ## Ornek

      add(
        [%{role: "user", content: "Ben Ilker Kaan. Elixir/Phoenix ile gelistirme yapiyorum."}],
        "ilkerkaan"
      )
  """
  @spec add([map()], String.t(), keyword()) :: Mem0Result.t()
  def add(messages, user_id, opts \\ []) when is_list(messages) and is_binary(user_id) do
    payload = %{
      messages: messages,
      user_id: user_id,
      # kaynak etiketi (opsiyonel)
      source: "ilkerkaan"
    }

    request("/memories/", :post, payload, opts)
  end

  @doc """
  Kullanici/agent bazli hafiza aramasi.
  """
  @spec search(String.t(), String.t(), keyword()) :: Mem0Result.t()
  def search(query, user_id, opts \\ []) when is_binary(query) and is_binary(user_id) do
    payload = %{
      query: query,
      user_id: user_id
    }

    request("/memories/search/", :post, payload, opts)
  end

  @doc """
  Bir kullanicinin tum hafizalarini listele.
  """
  @spec list(String.t(), keyword()) :: Mem0Result.t()
  def list(user_id, opts \\ []) when is_binary(user_id) do
    request("/memories/?user_id=#{URI.encode_www_form(user_id)}", :get, nil, opts)
  end

  # -----------------------------------------------------------------
  # HTTP Helpers
  # -----------------------------------------------------------------

  defp request(path, method, payload, _opts) do
    url = @base_url <> path
    headers = [{"Authorization", "Token #{api_key()}"}, {"Content-Type", "application/json"}]

    req =
      case method do
        :get ->
          Req.new(method: :get, url: url, headers: headers, receive_timeout: @timeout)

        :post ->
          Req.new(
            method: :post,
            url: url,
            headers: headers,
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
    Application.get_env(:agentbot_core, :mem0_api_key) ||
      System.get_env("MEM0_API_KEY") ||
      raise(
        "MEM0_API_KEY is not configured. Set :agentbot_core, :mem0_api_key or env MEM0_API_KEY"
      )
  end
end
