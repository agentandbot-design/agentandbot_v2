defmodule AgentbotCore.Repo.Migrations.CreateProvisioningProviders do
  @moduledoc """
  Provisioning provider'lar — fly.io, railway, render, aws...

  Affiliate URL şablonu, prerequisites ve metadata içerir.
  QM'deki "target.provider-registry" felsefesinden.
  """

  use Ecto.Migration

  def change do
    create table(:provisioning_providers, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:name, :string, null: false)
      add(:slug, :string, null: false)

      add(:referral_url_template, :string, null: false)
      add(:referral_code, :string)

      add(:prerequisites, :jsonb, default: fragment("'[]'::jsonb"))
      add(:status, :string, default: "active")

      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:provisioning_providers, [:slug]))
    create(index(:provisioning_providers, [:status]))
  end
end
