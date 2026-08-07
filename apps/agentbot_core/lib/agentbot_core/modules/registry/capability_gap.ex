defmodule AgentbotCore.Modules.Registry.CapabilityGap do
  @moduledoc """
  Capability Gap — talep edilen ama sağlayıcısı olmayan yetenek.

  "En çok talep edilen ama karşılanamayan yetenekler" listesi.
  Ekosistemdeki katkıcılar boşluğu görür ve doldurur.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :capability_name, :requested_count, :last_requested_at, :fulfilled, :fulfilled_by, :inserted_at]}
  alias AgentbotCore.Repo

  schema "capability_gaps" do
    field :capability_name, :string
    field :requested_count, :integer, default: 1
    field :last_requested_at, :utc_datetime
    field :fulfilled, :boolean, default: false
    field :fulfilled_by, :string
    field :fulfilled_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(gap, attrs) do
    gap
    |> cast(attrs, [:capability_name, :requested_count, :last_requested_at, :fulfilled, :fulfilled_by, :fulfilled_at])
    |> validate_required([:capability_name])
    |> unique_constraint(:capability_name)
  end

  @doc "Talep edilen capability kaydet — yoksa oluştur, varsa sayacı artır"
  def record_request(capability_name) do
    case Repo.get_by(__MODULE__, capability_name: capability_name) do
      nil ->
        %__MODULE__{}
        |> changeset(%{capability_name: capability_name, last_requested_at: DateTime.utc_now()})
        |> Repo.insert()

      existing ->
        existing
        |> changeset(%{
          requested_count: existing.requested_count + 1,
          last_requested_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  @doc "Gap'i dolduruldu olarak işaretle"
  def fulfill(capability_name, agent_id) do
    case Repo.get_by(__MODULE__, capability_name: capability_name) do
      nil -> {:error, :not_found}
      gap ->
        gap
        |> changeset(%{fulfilled: true, fulfilled_by: agent_id, fulfilled_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc "En çok talep edilen ama karşılanamayan capability'leri listele"
  def list_top_gaps(limit \\ 20) do
    __MODULE__
    |> where([g], g.fulfilled == false)
    |> order_by([g], desc: g.requested_count)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Doldurulmamış gap'leri listele"
  def list_unfulfilled do
    __MODULE__
    |> where([g], g.fulfilled == false)
    |> order_by([g], desc: g.last_requested_at)
    |> Repo.all()
  end
end
