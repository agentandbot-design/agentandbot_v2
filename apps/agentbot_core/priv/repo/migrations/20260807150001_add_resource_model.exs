defmodule AgentbotCore.Repo.Migrations.AddResourceModel do
  @moduledoc """
  Resource model — executor'lar ne sağlar, task'lar ne ister.

  "Gel CPU ver para kazan. Gel API bağla para kazan."

  Bauhaus: sadece gerekli alanlar.
  """

  use Ecto.Migration

  def change do
    # ── Executor sağladığı kaynaklar ──
    # Bir executor birden fazla kaynak sağlayabilir
    create table(:executor_resources) do
      add :agent_credential_id, references(:agent_credentials, on_delete: :delete_all), null: false
      add :resource_type, :string, null: false  # cpu, ram, gpu, storage, api, bandwidth
      add :amount, :integer                        # MB (ram/storage), cores (cpu/gpu), calls/day (api)
      add :unit, :string                           # MB, cores, GB, calls, mbps
      add :cost_per_unit, :decimal, precision: 10, scale: 4  # kredi/ünit (şimdilik 0)
      add :available, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:executor_resources, [:agent_credential_id])
    create index(:executor_resources, [:resource_type])
    create index(:executor_resources, [:available])

    # ── Task gereksinimleri ──
    # Bir task belirli kaynaklara ihtiyaç duyabilir
    create table(:task_requirements) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :resource_type, :string, null: false  # cpu, ram, gpu, api, ...
      add :min_amount, :integer                  # minimum gereksinim
      add :unit, :string
      add :optional, :boolean, default: false    # zorunlu mu tercih mi

      timestamps(type: :utc_datetime)
    end

    create index(:task_requirements, [:task_id])
    create index(:task_requirements, [:resource_type])
  end
end
