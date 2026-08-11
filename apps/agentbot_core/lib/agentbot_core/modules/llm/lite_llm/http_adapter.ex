defmodule LiteLLM.HTTPAdapter do
  @behaviour LiteLLM.Client
  require Logger

  def create_key(user_id, model, opts \\ %{}, config) do
    url = "#{config[:base_url]}/key/generate"
    body = Map.merge(opts, %{"user_id" => user_id, "models" => [model]})
    
    case Req.post(url, json: body, headers: auth_headers(config)) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> 
        Logger.error("LiteLLM Key Creation Failed: #{status} - #{inspect(body)}")
        {:error, :api_error}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_usage(key_id, config) do
    url = "#{config[:base_url]}/spend/keys"
    params = if key_id, do: [key_id: key_id], else: []
    
    case Req.get(url, params: params, headers: auth_headers(config)) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  def healthy?(config) do
    case Req.get("#{config[:base_url]}/health", headers: auth_headers(config)) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  # Behaviour implementation for healthy?/0
  def healthy?() do
    # Default behavior or configuration-based health check
    false
  end

  defp auth_headers(config) do
    [{"Authorization", "Bearer #{config[:master_key]}"}]
  end
end
