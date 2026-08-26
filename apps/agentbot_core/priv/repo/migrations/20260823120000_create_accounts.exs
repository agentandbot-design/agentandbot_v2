defmodule AgentbotCore.Repo.Migrations.CreateAccounts do
  @moduledoc """
  Hesaplar — insan kullanıcılar.

  QM (qm.agentandbot.com) ortak girişinden gelen e-posta kimliği burada
  atanır; agent_credentials ajanlar içindir, accounts insanlar içindir.
  """

  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:email, :string, null: false)
      add(:display_name, :string)
      add(:last_signed_in_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:accounts, [:email]))
  end
end
