defmodule AgentbotCore.Modules.Security.CapabilityCheck do
  @moduledoc """
  Yetenek kontrolü — ajanların hangi işlemleri yapabileceğini denetler.

  Plug olarak da kullanılabilir.
  """

  @doc """
  Yetenek listesini kontrol eder.
  """
  @spec check([String.t()], String.t()) :: :ok | {:error, String.t()}
  def check(agent_capabilities, required) do
    if "admin" in agent_capabilities or required in agent_capabilities do
      :ok
    else
      {:error, "Yetkiniz yok: #{required}"}
    end
  end

  @doc """
  Birden fazla yetenek kontrolü — hepsi gerekli (AND).
  """
  @spec check_all([String.t()], [String.t()]) :: :ok | {:error, String.t()}
  def check_all(agent_capabilities, required_list) do
    Enum.reduce_while(required_list, :ok, fn required, _acc ->
      case check(agent_capabilities, required) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Herhangi bir yetenek yeterli (OR).
  """
  @spec check_any([String.t()], [String.t()]) :: :ok | {:error, String.t()}
  def check_any(agent_capabilities, required_list) do
    if Enum.any?(required_list, &(&1 in agent_capabilities)) or "admin" in agent_capabilities do
      :ok
    else
      {:error, "Hiçbir gerekli yeteneğe sahip değilsiniz"}
    end
  end
end
