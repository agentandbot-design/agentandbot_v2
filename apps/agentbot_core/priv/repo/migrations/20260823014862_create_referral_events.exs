defmodule AgentbotCore.Repo.Migrations.CreateReferralEvents do
  @moduledoc """
  Referral/Attribution event'leri — affiliate kazanç takibi.

  Agent referral link ile deploy yapar, AB bu event'i kaydeder.
  Provider'dan gelecek komisyon bildirimi ile eşleşir.
  """

  use Ecto.Migration

  def change do
    create table(:referral_events, primary_key: false) do
      add(:id, :bigserial, primary_key: true)

      add(:provider_id, references(:provisioning_providers, on_delete: :restrict), null: false)

      add(:deployment_id, references(:provisioning_deployments, on_delete: :delete_all),
        null: false
      )

      add(:event_type, :string, null: false)

      add(:attribution_code, :string, null: false)
      add(:referral_link, :string)

      add(:occurred_at, :utc_datetime, default: fragment("NOW()"))

      add(:metadata, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(index(:referral_events, [:provider_id]))
    create(index(:referral_events, [:deployment_id]))
    create(index(:referral_events, [:event_type]))
    create(index(:referral_events, [:attribution_code]))
    create(index(:referral_events, [:occurred_at]))
  end
end
