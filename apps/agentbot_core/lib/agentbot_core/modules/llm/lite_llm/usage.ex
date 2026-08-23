defmodule LiteLLM.Usage do
  @moduledoc """
  LiteLLM kullanım kaydı — key bazlı spend ve token verisi.
  """

  defstruct [:key_id, :user_id, :model, :spend, :total_tokens, :timestamp]
end
