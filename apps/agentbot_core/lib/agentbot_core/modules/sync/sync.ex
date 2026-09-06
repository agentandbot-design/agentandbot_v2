defmodule AgentbotCore.Modules.Sync do
  @moduledoc """
  Sync motoru — AgentAndBot tek kaynak, dış sistemler yansıma.

  Akış:
  - Task write → `mark_dirty/1` → sync_state=dirty
  - Oban worker (30sn debounce) → `run/1`
  - Her aktif hedef için adapter.push; hepsi başarılıysa in_sync, yoksa conflict

  Çakışma kuralı: AgentAndBot kazanır. Dış sistemden gelen değişiklik yalnızca
  task `in_sync` durumundayken uygulanır; dirty/conflict'te AB tarafı dışarı yazılır.

  Yeni adapter eklemek: `sync/` altında Adapter behaviour'ı implemente eden modül +
  `sync_targets`'a satır. Registry otomatik (modül listesi sabit, config tablodan).
  """

  import Ecto.Query
  alias AgentbotCore.Repo
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Sync.SyncLog

  # Adapter registry — yeni adapter buraya eklenir
  @adapters %{
    "github" => AgentbotCore.Modules.Sync.GithubAdapter,
    "hermes" => AgentbotCore.Modules.Sync.HermesAdapter
  }

  def adapters, do: @adapters

  @doc "Task'ı dirty işaretle (her write sonrası çağrılır)"
  def mark_dirty(task_id) do
    from(t in Task, where: t.id == ^task_id and t.sync_state != "conflict")
    |> Repo.update_all(set: [sync_state: "dirty"])
    :ok
  end

  @doc "Dirty task'ı tüm aktif outbound hedeflere push et"
  def run(task_id) do
    task = Repo.get!(Task, task_id)
    targets = active_targets("outbound")

    results =
      Enum.reduce(targets, %{meta: task.sync_metadata || %{}, ok: true}, fn target, acc ->
        adapter = @adapters[target.system]

        case adapter && adapter.push(Map.get(target.state || %{}, "adapter", %{}), task, config: target.config) do
          {:ok, ext_id, new_adapter_state} ->
            meta =
              Map.put(acc.meta, target.system, %{
                "external_id" => ext_id,
                "last_synced_at" => DateTime.to_iso8601(DateTime.utc_now()),
                "direction" => target.direction
              })

            SyncLog.log(task.id, target.system, "outbound", "pushed",
              fields: Map.keys(Map.take(task, [:title, :summary, :status, :assigned_to]))
            )

            state = Map.put(target.state || %{}, "adapter", new_adapter_state)
            Repo.update_all(from(s in AgentbotCore.Modules.Sync.SyncTarget, where: s.id == ^target.id), set: [state: state])
            %{acc | meta: meta}

          {:skip, reason} ->
            SyncLog.log(task.id, target.system, "outbound", "skipped", detail: reason)
            acc

          {:error, err} ->
            SyncLog.log(task.id, target.system, "outbound", "error", detail: inspect(err, limit: 200))
            %{acc | ok: false}

          nil ->
            SyncLog.log(task.id, target.system, "outbound", "error", detail: "adapter not found")
            %{acc | ok: false}
        end
      end)

    sync_state = if results.ok, do: "in_sync", else: "conflict"
    task |> Ecto.Changeset.change(sync_state: sync_state, sync_metadata: results.meta) |> Repo.update!()
    {:ok, sync_state}
  end

  @doc "Inbound değişikliği uygula — AB kazanır kuralı"
  def apply_inbound(system, external_id, changes) do
    task = find_by_external_id(system, external_id)

    cond do
      task == nil ->
        {:error, :not_found}

      task.sync_state == "in_sync" ->
        # ponytail: doğrudan update — updated_by sync kaynağını işaretler, event log değişikliği yazar
        attrs = Map.merge(changes, %{"updated_by" => "sync:#{system}"})
        Task.update(task, attrs)

      true ->
        SyncLog.log(task.id, system, "inbound", "ab_won",
          fields: Map.keys(changes),
          detail: "AB dirty/conflict — dış değişiklik reddedildi, AB dışarı yazılacak"
        )

        {:conflict, :ab_won}
    end
  end

  def active_targets(direction) do
    from(s in AgentbotCore.Modules.Sync.SyncTarget,
      where: s.enabled == true and s.direction in ^match_directions(direction)
    )
    |> Repo.all()
  end

  defp match_directions("outbound"), do: ["outbound", "two_way"]
  defp match_directions("inbound"), do: ["inbound", "two_way"]
  defp match_directions("two_way"), do: ["two_way"]

  defp find_by_external_id(system, external_id) do
    ext_id = to_string(external_id)

    from(t in Task,
      where:
        fragment("? -> ? ->> 'external_id' = ?", t.sync_metadata, ^system, ^ext_id),
      order_by: [desc: t.updated_at],
      limit: 1
    )
    |> Repo.one()
  end
end