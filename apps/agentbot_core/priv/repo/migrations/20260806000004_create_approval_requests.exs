defmodule AgentbotCore.Repo.Migrations.CreateApprovalRequests do
  @moduledoc "Onay talepleri tablosu"

  use Ecto.Migration

  def change do
    create table(:approval_requests, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:room_id, references(:rooms, on_delete: :nilify_all))
      add(:requester_id, :string, null: false)
      add(:requester_name, :string)
      add(:title, :string, null: false)
      add(:description, :text)
      add(:status, :string, default: "pending")
      add(:resolved_by, :string)
      add(:resolution_note, :text)
      add(:expires_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:approval_requests, [:status]))
    create(index(:approval_requests, [:requester_id]))
  end
end
