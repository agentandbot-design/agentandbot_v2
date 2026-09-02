defmodule AgentbotCore.Modules.Security.AgentCredential do
  @moduledoc """
  Ajan kimlik bilgileri — token tabanlı kimlik yönetimi.

  Ecto schema ile veritabanında saklanır.
  Ed25519 henüz yok, basit token saklama.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :agent_id,
             :agent_name,
             :executor_type,
             :endpoint,
             :capabilities,
             :protocols,
             :description,
             :expires_at,
             :is_active,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo

  schema "agent_credentials" do
    field(:agent_id, :string)
    field(:agent_name, :string)
    field(:token_hash, :string)
    field(:public_key, :string)
    field(:capabilities, {:array, :string}, default: [])
    field(:protocols, {:array, :string}, default: ["rest"])
    field(:description, :string)
    field(:executor_type, :string, default: "agent")
    # agent | tool | script | workflow | mcp | api | container
    field(:endpoint, :string)
    # MCP: http://host:3001 | CLI: blender | API: https://... | n8n://workflow/183
    field(:expires_at, :utc_datetime)
    field(:is_active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  @doc "Yeni credential oluşturmak için changeset"
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [
      :agent_id,
      :agent_name,
      :token_hash,
      :public_key,
      :capabilities,
      :protocols,
      :description,
      :executor_type,
      :endpoint,
      :expires_at,
      :is_active
    ])
    |> validate_required([:agent_id, :agent_name, :token_hash])
    |> validate_length(:agent_id, min: 1, max: 100)
    |> validate_length(:agent_name, min: 1, max: 200)
  end

  @doc "Token ile credential bulur"
  def find_by_token(token) when is_binary(token) do
    hash = hash_token(token)

    __MODULE__
    |> where([c], c.token_hash == ^hash and c.is_active == true)
    |> Repo.one()
  end

  @doc "Ajan ID ile aktif credential'ları bulur"
  def find_by_agent_id(agent_id) do
    __MODULE__
    |> where([c], c.agent_id == ^agent_id and c.is_active == true)
    |> Repo.all()
  end

  @doc "Capability'ye sahip aktif agent'ları bulur (Discovery)"
  def find_by_capability(capability) when is_binary(capability) do
    __MODULE__
    |> where([c], c.is_active == true and ^capability in c.capabilities)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc "Yeni token kaydeder"
  def register(attrs) do
    with token <- generate_token(),
         hash <- hash_token(token),
         attrs <- Map.put(attrs, :token_hash, hash) do
      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, credential} -> {:ok, Map.put(credential, :plain_token, token)}
        error -> error
      end
    end
  end

  @doc "Credential'ı devre dışı bırak"
  def revoke(id) do
    __MODULE__
    |> where([c], c.id == ^id)
    |> Repo.update_all(set: [is_active: false])
  end

  @doc "Tüm aktif agent manifest'lerini listele — #23"
  def list_active_manifests do
    __MODULE__
    |> where([c], c.is_active == true)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
    |> Enum.map(&to_manifest/1)
  end

  @doc "Tek agent manifest'i getir — #23"
  def find_manifest(agent_id) do
    __MODULE__
    |> where([c], c.agent_id == ^agent_id and c.is_active == true)
    |> Repo.one()
    |> case do
      nil -> nil
      cred -> to_manifest(cred)
    end
  end

  @doc "Credential → Manifest dönüşümü"
  def to_manifest(%__MODULE__{} = c) do
    %{
      schema: "agentandbot.manifest/v1",
      agent_id: c.agent_id,
      agent_name: c.agent_name,
      executor_type: c.executor_type,
      capabilities: c.capabilities,
      protocols: c.protocols,
      endpoint: c.endpoint,
      description: c.description,
      version: Map.get(c, :version, "0.1.0"),
      is_active: c.is_active,
      signed_at: DateTime.to_iso8601(c.updated_at || c.inserted_at),
      links: %{
        self: "/api/agents/#{c.agent_id}/manifest",
        skill: "/.agent-well-known/skill",
        protocols: "/.agent-well-known/protocols"
      }
    }
  end

  # Token hash — SHA256
  defp hash_token(token) do
    Base.encode16(:crypto.hash(:sha256, token), case: :lower)
  end

  # Rastgele token üret — 32 byte
  defp generate_token do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end
end
