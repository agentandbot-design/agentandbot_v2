defmodule AgentbotCore.Modules.Registry.Capability do
  @moduledoc """
  Capability — mimarinin merkezi nesnesi.

  Agent değil, Capability birincildir. Agent'lar capability sağlar (provider).
  Capability yoksa → Capability Gap olarak kaydedilir.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [:id, :name, :description, :category, :status, :inserted_at, :updated_at]}
  alias AgentbotCore.Repo

  schema "capabilities" do
    field(:name, :string)
    field(:description, :string)
    field(:category, :string)
    field(:status, :string, default: "active")
    # JSON
    field(:metadata, :string)

    has_many(:agent_capabilities, AgentbotCore.Modules.Registry.AgentCapability)

    timestamps(type: :utc_datetime)
  end

  def changeset(capability, attrs) do
    capability
    |> cast(attrs, [:name, :description, :category, :status, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  @doc "Capability oluştur (veya varsa getir)"
  def find_or_create(name, opts \\ %{}) do
    case Repo.get_by(__MODULE__, name: name) do
      nil ->
        %__MODULE__{}
        |> changeset(%{
          name: name,
          description: Map.get(opts, :description) || Map.get(opts, "description"),
          category: Map.get(opts, :category) || Map.get(opts, "category")
        })
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc "İsme göre capability bul"
  def get_by_name(name), do: Repo.get_by(__MODULE__, name: name)

  @doc "Tüm aktif capability'leri listele"
  def list_active do
    __MODULE__ |> where([c], c.status == "active") |> Repo.all()
  end

  @doc "Kategoriye göre listele"
  def list_by_category(category) do
    __MODULE__ |> where([c], c.category == ^category) |> Repo.all()
  end

  @doc "Bir capability için provider'ları (executor'ları) listele"
  def providers(capability_name) do
    __MODULE__
    |> join(:inner, [c], ac in assoc(c, :agent_capabilities))
    |> join(:inner, [c, ac], cred in assoc(ac, :agent_credential))
    |> where([c, ac, cred], c.name == ^capability_name and cred.is_active == true)
    |> select([c, ac, cred], %{
      agent_id: cred.agent_id,
      agent_name: cred.agent_name,
      executor_type: cred.executor_type,
      endpoint: cred.endpoint,
      verified: ac.verified,
      tasks_completed: ac.tasks_completed,
      tasks_failed: ac.tasks_failed,
      success_rate: ac.success_rate
    })
    |> order_by([c, ac, cred], desc: ac.tasks_completed)
    |> Repo.all()
  end
end
