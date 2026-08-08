defmodule AgentbotCore.Modules.Registry.ExecutorResource do
  @moduledoc """
  Executor sağladığı kaynaklar — CPU, RAM, GPU, Storage, API, Bandwidth.

  "Gel CPU ver para kazan. Gel API bağla para kazan."

  Bir executor kayıt olurken ne sağladığını bildirir.
  Task'lar gereksinimlerini bildirir, sistem eşleştirir.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :resource_type, :amount, :unit, :cost_per_unit, :available]}
  alias AgentbotCore.Repo

  schema "executor_resources" do
    belongs_to :agent_credential, AgentbotCore.Modules.Security.AgentCredential

    field :resource_type, :string    # cpu, ram, gpu, storage, api, bandwidth
    field :amount, :integer          # MB, cores, GB, calls, mbps
    field :unit, :string             # MB, cores, GB, calls/day, mbps
    field :cost_per_unit, :decimal   # kredi/ünit (şimdilik 0 — economy sonra)
    field :available, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @resource_types ~w(cpu ram gpu storage api bandwidth)

  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [:agent_credential_id, :resource_type, :amount, :unit, :cost_per_unit, :available])
    |> validate_required([:agent_credential_id, :resource_type, :amount])
    |> validate_inclusion(:resource_type, @resource_types)
  end

  @doc "Bir executor'a kaynak ekle"
  def add(agent_credential_id, resource_type, amount, unit, cost \\ nil) do
    %__MODULE__{}
    |> changeset(%{
      agent_credential_id: agent_credential_id,
      resource_type: resource_type,
      amount: amount,
      unit: unit,
      cost_per_unit: cost
    })
    |> Repo.insert()
  end

  @doc "Bir executor'ın tüm kaynaklarını listele"
  def list_by_executor(agent_credential_id) do
    __MODULE__
    |> where([r], r.agent_credential_id == ^agent_credential_id and r.available == true)
    |> Repo.all()
  end

  @doc "Kaynak tipine göre sağlayıcıları bul"
  def find_providers(resource_type, min_amount \\ 0) do
    __MODULE__
    |> join(:inner, [r], c in assoc(r, :agent_credential))
    |> where([r, c], r.resource_type == ^resource_type and r.amount >= ^min_amount and r.available == true and c.is_active == true)
    |> select([r, c], %{
      agent_id: c.agent_id,
      agent_name: c.agent_name,
      executor_type: c.executor_type,
      resource_type: r.resource_type,
      amount: r.amount,
      unit: r.unit,
      cost_per_unit: r.cost_per_unit
    })
    |> order_by([r, c], asc: r.cost_per_unit)
    |> Repo.all()
  end

  @doc "Tüm sistem kaynak özeti"
  def summary do
    __MODULE__
    |> where([r], r.available == true)
    |> group_by([r], [r.resource_type, r.unit])
    |> select([r], %{
      resource_type: r.resource_type,
      unit: r.unit,
      total_amount: sum(r.amount),
      provider_count: count(r.id)
    })
    |> Repo.all()
  end

  @doc "Desteklenen kaynak tipleri"
  def resource_types, do: @resource_types
end
