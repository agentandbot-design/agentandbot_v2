defmodule AgentbotCore.Repo.Migrations.CreateRooms do
  @moduledoc "Odalar tablosu"

  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:room_type, :string, default: "general")
      add(:max_agents, :integer, default: 50)
      add(:is_active, :boolean, default: true)

      timestamps(type: :utc_datetime)
    end

    create(index(:rooms, [:is_active]))
    create(index(:rooms, [:room_type]))
  end
end
