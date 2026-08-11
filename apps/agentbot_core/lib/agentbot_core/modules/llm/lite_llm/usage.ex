defmodule LiteLLM.Usage do
  defstruct [:key_id, :user_id, :model, :spend, :total_tokens, :timestamp]
end
