defmodule AgentbotCore.Modules.Provisioning.Recipe do
  @moduledoc """
  Recipe Contract v1 — capability sağlamak için standart reçete formatı.

  QM deployment directory'den ilhamla: manifest, skill, verify checklist,
  content-hash ile versiyonlanmış immutable record.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "provisioning_recipes" do
    field(:name, :string)

    field(:capability_name, :string)
    belongs_to(:provider, AgentbotCore.Modules.Provisioning.Provider)

    field(:contract_version, :integer, default: 1)

    field(:manifest, :map)
    field(:skill, :string)
    field(:verify_checklist, :map)

    field(:content_hash, :string)

    field(:estimated_cost, :string)
    field(:source_repo, :string)

    field(:status, :string, default: "active")

    field(:metadata, :map)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [
      :name,
      :capability_name,
      :provider_id,
      :contract_version,
      :manifest,
      :skill,
      :verify_checklist,
      :content_hash,
      :estimated_cost,
      :source_repo,
      :status,
      :metadata
    ])
    |> validate_required([
      :name,
      :capability_name,
      :provider_id,
      :contract_version,
      :manifest,
      :skill,
      :content_hash
    ])
    |> unique_constraint(:name)
    |> validate_inclusion(:status, ["active", "deprecated"])
    |> validate_inclusion(:contract_version, [1])
    |> foreign_key_constraint(:provider_id)
  end
end
