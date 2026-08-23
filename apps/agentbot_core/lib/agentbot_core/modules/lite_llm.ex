defmodule LiteLLM do
  @moduledoc """
  Facade for LiteLLM operations.
  """

  def create_key(user_id, model, opts \\ %{}) do
    adapter().create_key(user_id, model, opts, config())
  end

  def fetch_usage(key_id \\ nil) do
    adapter().fetch_usage(key_id, config())
  end

  def healthy? do
    adapter().healthy?(config())
  end

  defp adapter, do: Application.get_env(:agent_bot_core, LiteLLM)[:adapter]
  defp config, do: Application.get_env(:agent_bot_core, LiteLLM.HTTPAdapter)
end
