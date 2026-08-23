defmodule AgentbotCore.Repo.Migrations.CreateProvisioningDeployments do
  @moduledoc """
  Agent'ların kendi hesaplarında açtığı deployment'lar.

  AB yönetmez, sadece tracks + live-verify eder. Attribution code ile
  referral kazancı bağlanır. QM'deki "agent acts with own credentials"
  felsefesinden.
  """

  use Ecto.Migration

  def change do
    create table(:provisioning_deployments, primary_key: false) do
      add(:id, :bigserial, primary_key: true)

      add(:agent_credential_id, references(:agent_credentials, on_delete: :delete_all),
        null: false
      )

      add(:recipe_id, references(:provisioning_recipes, on_delete: :delete_all), null: false)
      add(:provider_id, references(:provisioning_providers, on_delete: :restrict), null: false)

      add(:region, :string)
      add(:endpoint_url, :string)
      add(:health_path, :string, default: "/health")

      add(:attribution_code, :string, null: false)

      add(:status, :string, default: "provisioning")

      add(:verified_at, :utc_datetime)
      add(:last_health_at, :utc_datetime)
      add(:failed_reason, :text)

      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(index(:provisioning_deployments, [:agent_credential_id]))
    create(index(:provisioning_deployments, [:recipe_id]))
    create(index(:provisioning_deployments, [:provider_id]))
    create(index(:provisioning_deployments, [:attribution_code]))
    create(index(:provisioning_deployments, [:status]))
  end
end
