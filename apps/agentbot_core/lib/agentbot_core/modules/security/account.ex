defmodule AgentbotCore.Modules.Security.Account do
  @moduledoc """
  Hesap — insan kullanıcı kimliği.

  QM ortak girişinden (portal_session cookie) doğrulanan e-posta ile
  oluşturulur/güncellenir. E-posta alanı tekil, giriş anı kaydedilir.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias AgentbotCore.Repo

  schema "accounts" do
    field(:email, :string)
    field(:display_name, :string)
    field(:last_signed_in_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc "Hesap changeset'i"
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:email, :display_name, :last_signed_in_at])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unique_constraint(:email)
  end

  @doc "E-posta ile hesap bulur"
  def find_by_email(email) when is_binary(email) do
    __MODULE__
    |> where([a], a.email == ^email)
    |> Repo.one()
  end

  @doc """
  QM girişinden hesabı atar — yoksa oluşturur, varsa last_signed_in_at günceller.
  """
  def upsert_from_email(email) when is_binary(email) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    normalized = email |> String.trim() |> String.downcase()

    case find_by_email(normalized) do
      %__MODULE__{} = account ->
        account
        |> changeset(%{last_signed_in_at: now})
        |> Repo.update()

      nil ->
        %__MODULE__{}
        |> changeset(%{email: normalized, last_signed_in_at: now})
        |> Repo.insert()
    end
  end

  @doc "Tüm hesaplar — en yeni giriş önce"
  def list_accounts do
    __MODULE__
    |> order_by([a], desc_nulls_last: a.last_signed_in_at)
    |> Repo.all()
  end
end
