defmodule AgentbotCore.Workers.SyncWorker do
  @moduledoc """
  Oban worker — dirty task'ları debounce'lu dış sistemlere push eder.

  Kuyruk: sync (düşük öncelik). 30sn debounce: her mark_dirty bir job üretir,
  Oban unique + scheduled ile üst üste binen çalıştırmalar teke iner.
  """

  use Oban.Worker,
    queue: :sync,
    unique: [
      period: 30,
      fields: [:args],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    case AgentbotCore.Modules.Sync.run(task_id) do
      {:ok, "in_sync"} -> :ok
      {:ok, "conflict"} -> {:error, "sync conflict — retry"}
      # ponytail: task silinmişse sessizce tamam
      _ -> :ok
    end
  end
end
