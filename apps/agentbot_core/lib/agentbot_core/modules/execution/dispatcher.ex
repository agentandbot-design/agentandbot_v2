defmodule AgentbotCore.Modules.Execution.Dispatcher do
  @moduledoc """
  Execution Dispatcher — task atanınca executor'ı çağırır.

  Executor tipine göre dağıtım:
    - api      → HTTP POST webhook
    - mcp      → HTTP POST (MCP protocol)
    - workflow → HTTP POST webhook (n8n vb.)
    - tool     → HTTP POST (tool runner servis)
    - agent    → PubSub bildirimi (agent polling ile alır)
    - script   → HTTP POST (script runner)

  Dispatcher executor'ın endpoint'ine task'ı gönderir.
  Executor işi yapar, POST /api/tasks/:id/artifact ile sonucu döner.

  Bauhaus: HTTP dışındaki execution tipleri (CLI sandbox vb.) sonra.
  Şimdilik her şey HTTP üzerinden.
  """

  require Logger

  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

  import Ecto.Query

  @doc "Task'ı executor'a dispatch et"
  @spec dispatch(task_id :: integer()) :: {:ok, map()} | {:error, term()}
  def dispatch(task_id) do
    task = Task.get!(task_id)

    if task.status != "assigned" or is_nil(task.assigned_to) do
      {:error, :not_assigned}
    else
      executor = get_executor(task.assigned_to)

      if is_nil(executor) do
        {:error, :executor_not_found}
      else
        payload = build_payload(task, executor)
        do_dispatch(executor, payload)
      end
    end
  end

  # ── Private ───────────────────────────────────────

  defp get_executor(agent_id) do
    AgentCredential
    |> where([c], c.agent_id == ^agent_id and c.is_active == true)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp build_payload(task, executor) do
    %{
      task_id: task.id,
      capability: task.capability,
      title: task.title,
      description: task.description,
      input: task.input,
      room_id: task.room_id,
      executor: %{
        type: executor.executor_type,
        endpoint: executor.endpoint
      },
      callback: %{
        # Executor işi bitince buraya POST atar
        artifact_url: build_callback_url(task.id),
        status_url: "/api/tasks/#{task.id}/status"
      }
    }
  end

  defp do_dispatch(executor, payload) do
    case executor.executor_type do
      type when type in ["api", "mcp", "workflow", "tool", "script"] ->
        http_dispatch(executor, payload)

      "agent" ->
        # Agent'lar polling yapar — sadece bildirim gönder
        AgentbotCore.PubSub.broadcast(
          "agent:#{executor.agent_id}",
          "task_assigned",
          payload
        )

        # Task'ı in_progress yap
        Task.update_status(payload.task_id, "in_progress")

        {:ok, %{method: "pubsub", agent_id: executor.agent_id}}

      _ ->
        {:error, :unknown_executor_type}
    end
  end

  defp http_dispatch(executor, payload) do
    endpoint = executor.endpoint

    if is_nil(endpoint) or endpoint == "" do
      {:error, :no_endpoint}
    else
      # Task'ı in_progress yap
      Task.update_status(payload.task_id, "in_progress")

      body = Jason.encode!(payload)

      task =
        Elixir.Task.Supervisor.async_nolink(AgentbotCore.TaskSupervisor, fn ->
          http_post(endpoint, body)
        end)

      case Elixir.Task.yield(task, 30_000) do
        {:ok, {:ok, response}} ->
          {:ok, %{method: "http", status: response.status, body: response.body}}

        {:ok, {:error, reason}} ->
          Task.update_status(payload.task_id, "failed")
          {:error, reason}

        nil ->
          Elixir.Task.shutdown(task, :brutal_kill)
          # Timeout demek executor hala çalışıyor olabilir — başarılı say
          {:ok, %{method: "http", status: "timeout_pending"}}
      end
    end
  end

  defp http_post(url, body) do
    headers = [
      {"content-type", "application/json"},
      {"user-agent", "AgentAndBot/1.0"}
    ]

    case :httpc.request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", body},
           [{:timeout, 25_000}],
           []
         ) do
      {:ok, {{_, status, _}, _resp_headers, resp_body}} ->
        {:ok, %{status: status, body: to_string(resp_body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_callback_url(task_id) do
    base = Application.get_env(:agentbot_core, :base_url, "http://localhost:4000")
    "#{base}/api/tasks/#{task_id}/artifact"
  end
end
