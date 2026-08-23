defmodule AgentbotCore.Repo.Migrations.CreateAgentCredentials do
  @moduledoc "Ajan kimlik bilgileri tablosu"

  use Ecto.Migration

  def change do
    create table(:agent_credentials, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:agent_id, :string, null: false)
      add(:agent_name, :string, null: false)
      add(:token_hash, :string, null: false)
      add(:public_key, :string)
      add(:capabilities, {:array, :string}, default: [])
      add(:expires_at, :utc_datetime)
      add(:is_active, :boolean, default: true)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:agent_credentials, [:token_hash]))
    create(index(:agent_credentials, [:agent_id, :is_active]))
  end
end
