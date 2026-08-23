defmodule AgentbotCore.Repo.Migrations.LinkGapsToRecipes do
  @moduledoc """
  Capability gap'leri recipe'lerle bağlar.

  Gap varsa, onu dolduracak recipe'ler olabilir. Recipe'den deploy
  başarılı olursa gap otomatik fulfilled olur.
  """

  use Ecto.Migration

  def change do
    alter table(:capability_gaps) do
      add(:suggested_recipe_id, references(:provisioning_recipes, on_delete: :nilify_all))
    end

    create(index(:capability_gaps, [:suggested_recipe_id]))
  end
end
