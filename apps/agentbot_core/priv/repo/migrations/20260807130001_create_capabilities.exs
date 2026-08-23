defmodule AgentbotCore.Repo.Migrations.CreateCapabilities do
  @moduledoc """
  Capability Registry — mimarinin merkezi nesnesi.
  Agent değil, Capability birincildir.

  Bauhaus: sadece gerekli alanlar.
  """

  use Ecto.Migration

  def change do
    create table(:capabilities) do
      # ör: "code.review", "sap.fi.reconciliation"
      add(:name, :string, null: false)
      add(:description, :string)
      # code, sap, research, data, devops...
      add(:category, :string)
      # active, deprecated
      add(:status, :string, default: "active")
      # JSON — verification criteria, etc.
      add(:metadata, :text)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:capabilities, [:name]))
    create(index(:capabilities, [:category]))
    create(index(:capabilities, [:status]))

    # ── Agent ↔ Capability junction (provider relationship) ──
    create table(:agent_capabilities, primary_key: false) do
      add(:id, :bigserial, primary_key: true)

      add(:agent_credential_id, references(:agent_credentials, on_delete: :delete_all),
        null: false
      )

      add(:capability_id, references(:capabilities, on_delete: :delete_all), null: false)
      # human doğrulamış mı?
      add(:verified, :boolean, default: false)
      add(:tasks_completed, :integer, default: 0)
      add(:tasks_failed, :integer, default: 0)
      add(:success_rate, :decimal, precision: 5, scale: 2)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:agent_capabilities, [:agent_credential_id, :capability_id]))
    create(index(:agent_capabilities, [:capability_id]))
    create(index(:agent_capabilities, [:verified]))

    # ── Capability Gap — talep edilen ama sağlayıcısı olmayan ──
    create table(:capability_gaps) do
      # "sap.einvoice.validation"
      add(:capability_name, :string, null: false)
      # kaç kez talep edildi
      add(:requested_count, :integer, default: 1)
      add(:last_requested_at, :utc_datetime)
      # bir agent kaydedince true olur
      add(:fulfilled, :boolean, default: false)
      # agent_id
      add(:fulfilled_by, :string)
      add(:fulfilled_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:capability_gaps, [:capability_name]))
    create(index(:capability_gaps, [:fulfilled]))
    create(index(:capability_gaps, [:requested_count]))
  end
end
