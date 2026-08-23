defmodule AgentbotCore.Modules.Registry.McpServer do
  @moduledoc """
  MCP Registry — merkezi MCP sunucu yönetimi.

  Public MCP'leri her agent görebilir ve kullanabilir.
  Private MCP'ler (API key, token gömülü) sadece sahibi agent ve yetkilendirdikleri.

  Transport tipleri:
  - `http` — URL bazlı (cloud MCP'ler, Activepieces gibi)
  - `stdio` — command + args (npx, uvx ile çalışan local MCP'ler)

  Bu modül AgentAndBot'un MCP Registry'sidir.
  Tüm agent'lar buradan MCP keşfi yapar.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :transport_type,
             :url,
             :command,
             :args,
             :visibility,
             :tags,
             :owner_agent_id,
             :is_active,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo

  schema "mcp_servers" do
    # benzersiz isim (activepieces, filesystem, ...)
    field(:name, :string)
    # ne işe yarar
    field(:description, :string)
    # http | stdio
    field(:transport_type, :string)
    # HTTP transport URL
    field(:url, :string)
    # stdio transport command (npx, uvx)
    field(:command, :string)
    # stdio args (JSON array string)
    field(:args, :string)
    # encrypted JSON — auth credentials (private)
    field(:headers, :string)
    # public | private
    field(:visibility, :string)
    # virgülle ayrılmış etiketler
    field(:tags, :string)
    # private MCP'lerin sahibi
    field(:owner_agent_id, :string)
    field(:is_active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(server, attrs) do
    server
    |> cast(attrs, [
      :name,
      :description,
      :transport_type,
      :url,
      :command,
      :args,
      :headers,
      :visibility,
      :tags,
      :owner_agent_id,
      :is_active
    ])
    |> validate_required([:name, :transport_type, :visibility])
    |> validate_inclusion(:transport_type, ~w(http stdio))
    |> validate_inclusion(:visibility, ~w(public private))
    |> validate_required_if(:url, transport_type: "http")
    |> validate_required_if(:command, transport_type: "stdio")
    |> unique_constraint(:name)
  end

  defp validate_required_if(changeset, field, condition) do
    # condition is a keyword list like [transport_type: "http"]
    {cond_key, cond_value} = List.first(condition)

    if get_field(changeset, cond_key) == cond_value do
      validate_required(changeset, [field])
    else
      changeset
    end
  end

  @doc "Tüm public MCP sunucularını listele"
  def list_public do
    __MODULE__
    |> where([m], m.visibility == "public" and m.is_active == true)
    |> order_by([m], asc: m.name)
    |> Repo.all()
  end

  @doc "Bir agent'ın erişebildiği MCP'leri listele (public + kendi private'ları)"
  def list_for_agent(agent_id) do
    __MODULE__
    |> where(
      [m],
      (m.visibility == "public" and m.is_active == true) or
        (m.owner_agent_id == ^agent_id and m.is_active == true)
    )
    |> order_by([m], asc: m.name)
    |> Repo.all()
  end

  @doc "İsme göre MCP sunucu bul"
  def get_by_name(name), do: Repo.get_by(__MODULE__, name: name)

  @doc "İsme göre MCP sunucu bul (sadece agent erişebiliyorsa)"
  def get_by_name_for_agent(name, agent_id) do
    __MODULE__
    |> where(
      [m],
      m.name == ^name and m.is_active == true and
        (m.visibility == "public" or m.owner_agent_id == ^agent_id)
    )
    |> Repo.one()
  end

  @doc "MCP sunucu kaydet"
  def register(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "MCP sunucu güncelle"
  def update(server, attrs) do
    server
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "MCP sunucuyu sil (soft delete — is_active false)"
  def deactivate(server) do
    server
    |> change(%{is_active: false})
    |> Repo.update()
  end

  @doc "Etikete göre MCP ara"
  def search_by_tag(tag) do
    __MODULE__
    |> where([m], m.is_active == true and m.visibility == "public")
    |> where([m], ilike(m.tags, ^"%#{tag}%"))
    |> order_by([m], asc: m.name)
    |> Repo.all()
  end
end
