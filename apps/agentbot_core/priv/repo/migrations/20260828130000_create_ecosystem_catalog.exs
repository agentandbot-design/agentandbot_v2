defmodule AgentbotCore.Repo.Migrations.CreateEcosystemCatalog do
  use Ecto.Migration

  def change do
    create table(:ecosystem_entries) do
      add(:name, :string, null: false)
      add(:url, :string, null: false)
      add(:category, :string, null: false)
      # P0 = uretimde kritik, P1 = guclu aday, P2 = gelismekte/izleme
      add(:priority, :string, null: false, default: "P2")
      add(:notes, :text)
      # JSON string: {"last_checked": "...", "status": "...", "changes": "..."}
      add(:status, :string, default: "unknown")
      add(:last_checked_at, :utc_datetime)
      add(:added_by, :string, default: "human")
      add(:metadata, :string)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ecosystem_entries, [:url]))
    create(index(:ecosystem_entries, [:category]))
    create(index(:ecosystem_entries, [:priority]))
  end
end
