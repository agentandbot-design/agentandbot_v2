defmodule AgentbotCore.Modules.Provisioning.Deployment do
  @moduledoc """
  Agent'ların kendi hesaplarında açtığı deployment'lar.

  AB yönetmez, sadece tracks + live-verify eder. Attribution code ile
  referral kazancı bağlanır. QM'deki "agent acts with own credentials"
  felsefesinden.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "provisioning_deployments" do
    belongs_to(:agent_credential, AgentbotCore.Modules.Security.AgentCredential)
    belongs_to(:recipe, AgentbotCore.Modules.Provisioning.Recipe)
    belongs_to(:provider, AgentbotCore.Modules.Provisioning.Provider)

    field(:region, :string)
    field(:endpoint_url, :string)
    field(:health_path, :string, default: "/health")

    field(:attribution_code, :string)

    field(:status, :string, default: "provisioning")

    field(:verified_at, :utc_datetime)
    field(:last_health_at, :utc_datetime)
    field(:failed_reason, :string)

    field(:metadata, :map)

    # Timestamp'leri manuel olarak second-precision (DB: timestamp(0))
    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    deployment
    |> cast(attrs, [
      :agent_credential_id,
      :recipe_id,
      :provider_id,
      :region,
      :endpoint_url,
      :health_path,
      :attribution_code,
      :status,
      :verified_at,
      :last_health_at,
      :failed_reason,
      :metadata
    ])
    |> validate_required([
      :agent_credential_id,
      :recipe_id,
      :provider_id,
      :attribution_code,
      :status
    ])
    |> validate_inclusion(:status, ["provisioning", "verifying", "live", "failed"])
    |> put_change(:inserted_at, Map.get(attrs, :inserted_at, now))
    |> put_change(:updated_at, Map.get(attrs, :updated_at, now))
    |> foreign_key_constraint(:agent_credential_id)
    |> foreign_key_constraint(:recipe_id)
    |> foreign_key_constraint(:provider_id)
  end
end
