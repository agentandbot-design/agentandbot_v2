defmodule AgentbotCore.Modules.Sync.SyncLog do
  @moduledoc """
  SyncLog — her push/pull işleminin şeffaflık kaydı.

  outcome değerleri:
  - "pushed" / "skipped" / "error" — outbound
  - "ab_won" / "external_applied" — inbound çakışma çözümü
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "sync_logs" do
    belongs_to(:task, AgentbotCore.Modules.Marketplace.Task)
    field(:system, :string)
    field(:direction, :string)
    field(:outcome, :string)
    field(:fields, {:array, :string}, default: [])
    field(:detail, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:task_id, :system, :direction, :outcome, :fields, :detail])
    |> validate_required([:task_id, :system, :direction, :outcome])
    |> foreign_key_constraint(:task_id)
  end

  @doc "Tek satır log yaz"
  def log(task_id, system, direction, outcome, opts \\ []) do
    %__MODULE__{}
    |> changeset(%{
      task_id: task_id,
      system: system,
      direction: direction,
      outcome: outcome,
      fields: opts[:fields] || [],
      detail: opts[:detail]
    })
    |> AgentbotCore.Repo.insert()
  end

  def list_for_task(task_id, limit \\ 50) do
    import Ecto.Query

    AgentbotCore.Repo.all(
      from(l in __MODULE__,
        where: l.task_id == ^task_id,
        order_by: [desc: l.inserted_at],
        limit: ^limit
      )
    )
  end
end
