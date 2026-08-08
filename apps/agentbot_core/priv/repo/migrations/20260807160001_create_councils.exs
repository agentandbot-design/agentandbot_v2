defmodule AgentbotCore.Repo.Migrations.CreateCouncils do
  @moduledoc """
  Council — bir soruyu birden fazla agent'a dağıt, görüşleri topla.

  Konsey: tek soru → N agent → N görüş → sentez.
  """

  use Ecto.Migration

  def change do
    create table(:councils) do
      add :question, :text, null: false
      add :capability, :string                      # hangi capability'den agentlar çağrılacak
      add :created_by, :string, default: "human"
      add :status, :string, default: "open"         # open → gathering → synthesized → closed
      add :min_responses, :integer, default: 2      # en az kaç görüş beklensin
      add :synthesis, :text                         # toplanan görüşlerin sentezi
      add :synthesized_by, :string
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :deadline_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:councils, [:status])
    create index(:councils, [:capability])

    create table(:council_responses) do
      add :council_id, references(:councils, on_delete: :delete_all), null: false
      add :agent_id, :string, null: false
      add :agent_name, :string
      add :content, :text, null: false              # agent'ın görüşü
      add :stance, :string                          # support, oppose, neutral, alternative
      add :confidence, :decimal                     # 0.0 - 1.0
      add :metadata, :text                          # JSON

      timestamps(type: :utc_datetime)
    end

    create index(:council_responses, [:council_id])
    create index(:council_responses, [:agent_id])
  end
end
