defmodule LiteLLM.Client do
  @moduledoc """
  LiteLLM client behaviour — key üretimi ve usage sorguları.
  """

  @callback create_key(String.t(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, any()}
  @callback fetch_usage(String.t() | nil, keyword()) :: {:ok, list(map())} | {:error, any()}
  @callback healthy?() :: boolean()
end
