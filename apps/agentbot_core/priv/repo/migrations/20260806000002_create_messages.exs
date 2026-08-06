defmodule AgentbotCore.Repo.Migrations.CreateMessages do
  @moduledoc "Mesajlar tablosu"

  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :sender_id, :string, null: false
      add :sender_name, :string
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :event_type, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:room_id])
    create index(:messages, [:sender_id])
    create index(:messages, [:inserted_at])
  end
end
