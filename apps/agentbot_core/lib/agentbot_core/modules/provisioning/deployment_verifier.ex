defmodule AgentbotCore.Modules.Provisioning.DeploymentVerifier do
  @moduledoc """
  Deployment state machine + health poll — QM "check --live" felsefesi.

  provisioning → verifying → live/failed
  Health check'ler bounded backoff ile yapılır.
  """

  use GenServer
  require Logger

  alias AgentbotCore.Modules.Provisioning

  @max_retries 10
  @initial_backoff_ms 1_000
  @max_backoff_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @doc """
  Deployment'ı verify etmeye başla
  """
  def verify_deployment(deployment_id) do
    GenServer.call(__MODULE__, {:verify, deployment_id})
  end

  @impl true
  def handle_call({:verify, deployment_id}, _from, state) do
    {:reply, schedule_verify(deployment_id, 0), state}
  end

  @impl true
  def handle_info({:check_health, deployment_id, retry_count}, state) do
    case Provisioning.check_deployment_health(deployment_id) do
      {:ok, :healthy} ->
        Logger.info("Deployment #{deployment_id} verified: healthy")
        Provisioning.update_deployment_status(deployment_id, "live")
        {:noreply, state}

      {:error, reason} ->
        if retry_count >= @max_retries do
          Logger.error(
            "Deployment #{deployment_id} failed after #{@max_retries} retries: #{inspect(reason)}"
          )

          Provisioning.update_deployment_status(deployment_id, "failed", reason: inspect(reason))
          {:noreply, state}
        else
          backoff = calculate_backoff(retry_count)

          Logger.warning(
            "Deployment #{deployment_id} health check failed (#{retry_count}/#{@max_retries}): #{inspect(reason)}, retrying in #{backoff}ms"
          )

          schedule_verify(deployment_id, retry_count + 1, backoff)
          {:noreply, state}
        end
    end
  end

  defp schedule_verify(deployment_id, retry_count, backoff \\ @initial_backoff_ms) do
    Process.send_after(self(), {:check_health, deployment_id, retry_count}, backoff)
    {:ok, :scheduled}
  end

  defp calculate_backoff(retry_count) do
    backoff = @initial_backoff_ms * :math.pow(2, retry_count)
    round(min(backoff, @max_backoff_ms))
  end
end
