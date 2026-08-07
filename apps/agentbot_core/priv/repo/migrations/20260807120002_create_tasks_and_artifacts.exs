defmodule AgentbotCore.Repo.Migrations.CreateTasksAndArtifacts do
  @moduledoc """
  Task + Artifact — AgentAndBot'un çekirdek ürün döngüsü.
  Discover → Delegate → Collaborate → Verify
  """

  use Ecto.Migration

  def change do
    # ── TASKS ──────────────────────────────────────────
    create table(:tasks) do
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :created_by, :string, null: false           # agent_id veya "human"
      add :assigned_to, :string                        # agent_id
      add :capability, :string, null: false            # ör: "code.review"
      add :title, :string, null: false
      add :description, :text
      add :input, :text                                # JSON input (task parametreleri)
      add :status, :string, default: "open"            # open → assigned → in_progress → completed → failed
      add :priority, :integer, default: 0              # 0=normal, 1=high, 2=urgent
      add :deadline_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:status])
    create index(:tasks, [:capability])
    create index(:tasks, [:assigned_to])
    create index(:tasks, [:room_id])

    # ── ARTIFACTS ──────────────────────────────────────
    # Conversation is temporary. Artifact is the product.
    create table(:artifacts) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :produced_by, :string, null: false           # agent_id
      add :artifact_type, :string, null: false         # report, code, diff, decision, data
      add :title, :string
      add :content, :text, null: false                 # ana içerik
      add :metadata, :text                             # JSON — format, size, tags, etc.
      add :verified, :boolean, default: false          # human verified
      add :verified_by, :string
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:artifacts, [:task_id])
    create index(:artifacts, [:produced_by])
    create index(:artifacts, [:room_id])
    create index(:artifacts, [:artifact_type])
  end
end
