defmodule AgentbotCore.Modules.Registry.EcosystemEntry do
  @moduledoc """
  Ajan ekosistemi takip kataloğu — MCP, A2A, A2UI, OWASP, NIST gibi
  standartlar, protokoller, framework'ler ve araçlar.

  Agent'lar ve insanlar kategori bazlı giriş ekler; öncelik katmanları:
  P0 = üretimde kritik, P1 = güçlü aday/uygulama, P2 = gelişmekte/izleme.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias AgentbotCore.Repo

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :url,
             :category,
             :priority,
             :notes,
             :status,
             :last_checked_at,
             :added_by,
             :inserted_at,
             :updated_at
           ]}

  schema "ecosystem_entries" do
    field(:name, :string)
    field(:url, :string)
    field(:category, :string)
    field(:priority, :string, default: "P2")
    field(:notes, :string)
    field(:status, :string, default: "unknown")
    field(:last_checked_at, :utc_datetime)
    field(:added_by, :string, default: "human")
    field(:metadata, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:name, :url, :category, :priority, :notes, :status, :last_checked_at, :added_by, :metadata])
    |> validate_required([:name, :url, :category])
    |> validate_inclusion(:priority, ~w(P0 P1 P2))
    |> validate_inclusion(:status, ~w(unknown ok changed broken archived))
    |> unique_constraint(:url)
  end

  @doc "Kategoriye göre listele (öncelik sırasıyla)"
  def list_by_category(category) do
    from(e in __MODULE__,
      where: e.category == ^category,
      order_by: [asc: e.priority, asc: e.name]
    )
    |> Repo.all()
  end

  @doc "Tüm katalog — kategori + öncelik sıralı"
  def list_all do
    from(e in __MODULE__, order_by: [asc: e.category, asc: e.priority, asc: e.name])
    |> Repo.all()
  end

  @doc "Var olanı güncelle veya yenisini ekle (URL bazlı upsert)"
  def upsert(attrs) do
    case Repo.get_by(__MODULE__, url: attrs[:url] || attrs["url"]) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  @doc "Kategori istatistikleri"
  def category_stats do
    from(e in __MODULE__,
      group_by: [e.category, e.priority],
      select: {e.category, e.priority, count(e.id)}
    )
    |> Repo.all()
  end
end
