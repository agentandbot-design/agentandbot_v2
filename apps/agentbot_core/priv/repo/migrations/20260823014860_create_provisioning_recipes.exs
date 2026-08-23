defmodule AgentbotCore.Repo.Migrations.CreateProvisioningRecipes do
  @moduledoc """
  Recipe Contract v1 — capability sağlamak için standart reçete formatı.

  QM deployment directory'den ilhamla: manifest, skill, verify checklist,
  content-hash ile versiyonlanmış immutable record.
  """

  use Ecto.Migration

  def change do
    create table(:provisioning_recipes, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:name, :string, null: false)

      add(:capability_name, :string, null: false)
      add(:provider_id, references(:provisioning_providers, on_delete: :restrict), null: false)

      add(:contract_version, :integer, default: 1, null: false)

      add(:manifest, :jsonb, null: false)
      add(:skill, :text, null: false)
      add(:verify_checklist, :jsonb, default: fragment("'[]'::jsonb"))

      add(:content_hash, :string, null: false)

      add(:estimated_cost, :string)
      add(:source_repo, :string)

      add(:status, :string, default: "active")

      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:provisioning_recipes, [:name]))
    create(index(:provisioning_recipes, [:capability_name]))
    create(index(:provisioning_recipes, [:provider_id]))
    create(index(:provisioning_recipes, [:status]))
    create(index(:provisioning_recipes, [:content_hash]))
  end
end
