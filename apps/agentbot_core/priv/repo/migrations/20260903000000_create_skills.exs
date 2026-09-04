defmodule AgentbotCore.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills) do
      # benzersiz skill adı (ponytail, xlsx, arxiv, ...)
      add(:name, :string, null: false)
      # ne işe yarar — kısa açıklama
      add(:description, :string)
      # kategori (software-development, devops, research, ...)
      add(:category, :string)
      # skill versiyonu
      add(:version, :string, default: "1.0.0")
      # SKILL.md gövdesi (yaml frontmatter + markdown)
      add(:content, :text)
      # virgülle ayrılmış etiketler
      add(:tags, :string)
      # public | private
      add(:visibility, :string, default: "public")
      # public skill'lerin sahibi
      add(:owner_agent_id, :string)
      # kaynak (hermes, opencode, claude-code, github, ...)
      add(:source, :string)
      add(:is_active, :boolean, default: true)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:skills, [:name]))
    create(index(:skills, [:category]))
    create(index(:skills, [:visibility]))
  end
end
