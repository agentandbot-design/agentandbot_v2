defmodule AgentbotCore.Repo.Migrations.AddTagsToTasks do
  @moduledoc """
  Tasks tablosuna serbest etiketler (tags: #SAP #harezm #agentandbot vb.) alanını ekler.
  """
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add(:tags, :string)
    end

    create(index(:tasks, [:tags]))
  end
end
