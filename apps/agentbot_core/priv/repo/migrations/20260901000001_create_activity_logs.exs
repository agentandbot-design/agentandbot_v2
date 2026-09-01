defmodule AgentbotCore.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add(:date, :date, null: false)
      add(:title, :string, null: false)
      add(:content, :text, default: "")
      add(:tags, :string)
      add(:status, :string, default: "draft")
      add(:category, :string, default: "sap")
      add(:google_doc_id, :string)
      add(:google_doc_url, :string)
      add(:synced_at, :utc_datetime)
      add(:created_by, :string, default: "ilkerkaan")

      timestamps(type: :utc_datetime)
    end

    create(index(:activity_logs, [:date]))
    create(index(:activity_logs, [:status]))
    create(index(:activity_logs, [:category]))
  end
end
