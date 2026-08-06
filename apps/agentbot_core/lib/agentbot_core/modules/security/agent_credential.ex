defmodule AgentbotCore.Modules.Security.AgentCredential do
  @moduledoc """
  Ajan kimlik bilgileri — token tabanlı kimlik yönetimi.

  Ecto schema ile veritabanında saklanır.
  Ed25519 henüz yok, basit token saklama.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :agent_id, :agent_name, :capabilities, :expires_at, :is_active, :inserted_at, :updated_at]}
  alias AgentbotCore.Repo

  schema "agent_credentials" do
    field :agent_id, :string
    field :agent_name, :string
    field :token_hash, :string
    field :public_key, :string  # Ed25519 — gelecek phase
    field :capabilities, {:array, :string}, default: []
    field :expires_at, :utc_datetime
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc "Yeni credential oluşturmak için changeset"
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:agent_id, :agent_name, :token_hash, :public_key, :capabilities, :expires_at, :is_active])
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

  # Token hash — SHA256
  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end

  # Rastgele token üret — 32 byte
  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
