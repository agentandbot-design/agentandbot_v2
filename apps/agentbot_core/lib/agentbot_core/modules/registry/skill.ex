defmodule AgentbotCore.Modules.Registry.Skill do
  @moduledoc """
  Skill Registry — merkezi ajan skill kaydı.

  Agent'lar sahip oldukları skilleri buraya kaydeder; AgentAndBot'ta
  skill bölümünde yayınlanır ve keşfedilir.

  - Public skiller her agent görebilir ve indirebilir.
  - Private skiller sadece sahibi görebilir.

  Örnek kayıt: ponytail (lazy senior dev mode), xlsx, arxiv, github ...
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :category,
             :version,
             :content,
             :tags,
             :visibility,
             :owner_agent_id,
             :source,
             :is_active,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo

  schema "skills" do
    # benzersiz skill adı (ponytail, xlsx, ...)
    field(:name, :string)
    # ne işe yarar
    field(:description, :string)
    # kategori (software-development, devops, research, ...)
    field(:category, :string)
    # skill versiyonu
    field(:version, :string, default: "1.0.0")
    # SKILL.md gövdesi (yaml frontmatter + markdown)
    field(:content, :string)
    # virgülle ayrılmış etiketler
    field(:tags, :string)
    # public | private
    field(:visibility, :string, default: "public")
    # public skiller'in sahibi
    field(:owner_agent_id, :string)
    # kaynak (hermes, opencode, claude-code, github, ...)
    field(:source, :string)
    field(:is_active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [
      :name,
      :description,
      :category,
      :version,
      :content,
      :tags,
      :visibility,
      :owner_agent_id,
      :source,
      :is_active
    ])
    |> validate_required([:name])
    |> validate_inclusion(:visibility, ~w(public private))
    |> unique_constraint(:name)
  end

  @doc "Tüm aktif public skilleri listele"
  def list_public do
    Repo.all(
      from(s in __MODULE__,
        where: s.is_active == true and s.visibility == "public",
        order_by: [asc: s.category, asc: s.name]
      )
    )
  end

  @doc "Kategoriye göre public skiller"
  def list_by_category(category) do
    Repo.all(
      from(s in __MODULE__,
        where: s.is_active == true and s.visibility == "public" and s.category == ^category,
        order_by: [asc: s.name]
      )
    )
  end

  @doc "İsme göre skill ara (public ya da sahibi)"
  def get_by_name(name) do
    Repo.one(from(s in __MODULE__, where: s.name == ^name))
  end

  @doc "Etikete göre public skiller"
  def search_by_tag(tag) do
    Repo.all(
      from(s in __MODULE__,
        where:
          s.is_active == true and s.visibility == "public" and
            fragment("lower(?) LIKE ?", s.tags, ^"%#{String.downcase(tag)}%"),
        order_by: [asc: s.name]
      )
    )
  end

  @doc "Kategori listesi — sayfa filtresi için"
  def list_categories do
    Repo.all(
      from(s in __MODULE__,
        where: s.is_active == true and s.visibility == "public" and not is_nil(s.category),
        distinct: true,
        select: s.category,
        order_by: s.category
      )
    )
  end

  @doc "Bir agent'ın sahip olduğu skiller (public + kendi private)"
  def list_for_agent(agent_id) do
    Repo.all(
      from(s in __MODULE__,
        where: s.is_active == true and (s.visibility == "public" or s.owner_agent_id == ^agent_id),
        order_by: [asc: s.category, asc: s.name]
      )
    )
  end

  @doc "Yeni skill kaydet — varsa güncelle (upsert davranışı)"
  def register(attrs) do
    case get_by_name(attrs[:name] || attrs["name"]) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> changeset(Map.put(attrs, :is_active, true))
        |> Repo.update()
    end
  end

  @doc "Skill sil (deaktive et)"
  def delete(skill) do
    skill
    |> changeset(%{is_active: false})
    |> Repo.update()
  end

  @doc "Public görünüm — content dahil (keşif için)"
  def public_view(skill) do
    %{
      id: skill.id,
      name: skill.name,
      description: skill.description,
      category: skill.category,
      version: skill.version,
      content: skill.content,
      tags: skill.tags,
      source: skill.source,
      owner_agent_id: skill.owner_agent_id,
      inserted_at: skill.inserted_at,
      updated_at: skill.updated_at
    }
  end

  @doc "Sayfa görünümü — content hariç (liste için)"
  def card_view(skill) do
    %{
      id: skill.id,
      name: skill.name,
      description: skill.description,
      category: skill.category,
      version: skill.version,
      tags: skill.tags,
      source: skill.source,
      owner_agent_id: skill.owner_agent_id,
      updated_at: skill.updated_at
    }
  end
end
