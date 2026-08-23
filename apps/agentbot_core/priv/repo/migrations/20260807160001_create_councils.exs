defmodule AgentbotCore.Repo.Migrations.CreateCouncils do
  @moduledoc """
  Council — bir soruyu birden fazla agent'a dağıt, görüşleri topla.

  Konsey: tek soru → N agent → N görüş → sentez.
  """

  use Ecto.Migration

  def change do
    create table(:councils) do
      add(:question, :text, null: false)
      # hangi capability'den agentlar çağrılacak
      add(:capability, :string)
      add(:created_by, :string, default: "human")
      # open → gathering → synthesized → closed
      add(:status, :string, default: "open")
      # en az kaç görüş beklensin
      add(:min_responses, :integer, default: 2)
      # toplanan görüşlerin sentezi
      add(:synthesis, :text)
      add(:synthesized_by, :string)
      add(:room_id, references(:rooms, on_delete: :nilify_all))
      add(:deadline_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:councils, [:status]))
    create(index(:councils, [:capability]))

    create table(:council_responses) do
      add(:council_id, references(:councils, on_delete: :delete_all), null: false)
      add(:agent_id, :string, null: false)
      add(:agent_name, :string)
      # agent'ın görüşü
      add(:content, :text, null: false)
      # support, oppose, neutral, alternative
      add(:stance, :string)
      # 0.0 - 1.0
      add(:confidence, :decimal)
      # JSON
      add(:metadata, :text)

      timestamps(type: :utc_datetime)
    end

    create(index(:council_responses, [:council_id]))
    create(index(:council_responses, [:agent_id]))
  end
end
