defmodule AgentbotCore.Repo.Migrations.CreateTaskCommentsAndEvents do
  @moduledoc """
  Task yorumları (comments) ve faaliyet geçmişi (events) tablolarını oluşturur.
  Ek olarak tasks tablosuna parent_id ekler (alt görev desteği).
  """
  use Ecto.Migration

  def change do
    # ── task_comments: kart üzerindeki takım tartışmaları ──
    create table(:task_comments) do
      add(:task_id, references(:tasks, on_delete: :delete_all), null: false)
      add(:author, :string, null: false)
      add(:body, :text, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:task_comments, [:task_id]))
    create(index(:task_comments, [:author]))

    # ── task_events: tüm değişikliklerin zaman tüyü (audit trail) ──
    create table(:task_events) do
      add(:task_id, references(:tasks, on_delete: :delete_all), null: false)
      add(:actor, :string, null: false)
      add(:action, :string, null: false)
      # created | status_changed | assigned | commented | tagged | archived | deleted | edited
      add(:details, :map, default: %{})
      add(:inserted_at, :utc_datetime, null: false)
    end

    create(index(:task_events, [:task_id]))
    create(index(:task_events, [:action]))
    create(index(:task_events, [:inserted_at]))

    # ── tasks tablosuna parent_id + deadline_at zaten var, sadece parent_id ekle ──
    alter table(:tasks) do
      add(:parent_id, references(:tasks, on_delete: :nilify_all))
      add(:archived, :boolean, default: false, null: false)
    end

    create(index(:tasks, [:parent_id]))
    create(index(:tasks, [:archived]))
  end
end
