defmodule AgentbotCore.Repo.Migrations.AddKanbanSyncAndDualView do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add(:summary, :string)
      # Agent görünümü: bağımlılıklar, log/commit ref'leri, dosyalar, teknik notlar
      add(:technical_context, :map, default: %{})
      # Son güncelleyici: "human:ilker" | "agent:hermes" | "sync:github"
      add(:updated_by, :string)
      # Adapter state'leri: [%{system: "github", external_id: "123", ...}]
      add(:sync_metadata, :map, default: %{})
      # Outbound sync motoru durumu: in_sync | dirty | conflict
      add(:sync_state, :string, default: "in_sync")
    end

    create(index(:tasks, [:sync_state], where: "sync_state != 'in_sync'"))

    create table(:sync_logs) do
      add(:task_id, references(:tasks, on_delete: :delete_all), null: false)
      # "github" | "hermes" | adapter id
      add(:system, :string, null: false)
      # "outbound" | "inbound"
      add(:direction, :string, null: false)
      # "pushed" | "skipped" | "error" | "ab_won" | "external_applied"
      add(:outcome, :string, null: false)
      # Çakışan/aktarılan alan adları ["status","summary"]
      add(:fields, {:array, :string}, default: [])
      add(:detail, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:sync_logs, [:task_id]))
    create(index(:sync_logs, [:system, :direction]))

    create table(:sync_targets) do
      # Adapter id: "github" | "hermes" | ...
      add(:system, :string, null: false)
      # "off" | "outbound" | "two_way"
      add(:direction, :string, null: false, default: "off")
      # "webhook" | "poll"
      add(:trigger, :string, null: false, default: "webhook")
      # Alan haritası override + status_map + adapter'e özel config (repo, board vs.)
      add(:config, :map, default: %{})
      add(:enabled, :boolean, null: false, default: false)
      # Adapter pull cursor'u (son çekilen updated_at vb.)
      add(:state, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:sync_targets, [:system]))
  end
end