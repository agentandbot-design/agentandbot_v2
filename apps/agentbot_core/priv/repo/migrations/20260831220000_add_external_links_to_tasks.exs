defmodule AgentbotCore.Repo.Migrations.AddExternalLinksToTasks do
  @moduledoc """
  Tasks tablosuna harici bağlantı (GitHub, Google Drive, vb.) kolonlarını ekler.
  """
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add(:external_url, :string)
      add(:source_type, :string, default: "manual")
      # source_type: "manual" | "github" | "gdrive" | "github-issue" | "github-pr"
    end

    create(index(:tasks, [:source_type]))
    create(index(:tasks, [:external_url]))
  end
end
