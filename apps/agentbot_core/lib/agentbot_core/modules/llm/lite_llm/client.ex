defmodule LiteLLM.Client do
  @callback create_key(String.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, any()}
  @callback fetch_usage(String.t() | nil, keyword()) :: {:ok, list(map())} | {:error, any()}
  @callback healthy?() :: boolean()
end
