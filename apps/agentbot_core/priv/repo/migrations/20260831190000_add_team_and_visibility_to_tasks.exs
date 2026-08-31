defmodule AgentbotCore.Repo.Migrations.AddTeamAndVisibilityToTasks do
  @moduledoc """
  Tasks tablosuna takım (team) ve görünürlük (visibility: public | private) alanlarını ekler.
  """
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add(:team, :string, default: "core", null: false)
      add(:visibility, :string, default: "public", null: false)
    end

    create(index(:tasks, [:team]))
    create(index(:tasks, [:visibility]))
  end
end
