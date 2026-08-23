defmodule AgentbotCore.Modules.Provisioning.ReferralEvent do
  @moduledoc """
  Referral/Attribution event'leri — affiliate kazanç takibi.

  Agent referral link ile deploy yapar, AB bu event'i kaydeder.
  Provider'dan gelecek komisyon bildirimi ile eşleşir.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "referral_events" do
    belongs_to(:provider, AgentbotCore.Modules.Provisioning.Provider)
    belongs_to(:deployment, AgentbotCore.Modules.Provisioning.Deployment)

    field(:event_type, :string)

    field(:attribution_code, :string)
    field(:referral_link, :string)

    field(:occurred_at, :utc_datetime)

    field(:metadata, :map)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :provider_id,
      :deployment_id,
      :event_type,
      :attribution_code,
      :referral_link,
      :occurred_at,
      :metadata
    ])
    |> validate_required([:provider_id, :deployment_id, :event_type, :attribution_code])
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:deployment_id)
  end
end
