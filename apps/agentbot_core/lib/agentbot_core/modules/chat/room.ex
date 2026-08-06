defmodule AgentbotCore.Modules.Chat.Room do
  @moduledoc """
  Oda (Room) — ajanların bir araya geldiği iletişim alanı.

  Ecto schema ile veritabanında saklanır.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :name, :description, :room_type, :max_agents, :is_active, :inserted_at, :updated_at]}
  alias AgentbotCore.Repo

  schema "rooms" do
    field :name, :string
    field :description, :string
    field :room_type, :string, default: "general"  # general, task, approval
    field :max_agents, :integer, default: 50
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc "Yeni oda oluşturmak için changeset"
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :description, :room_type, :max_agents, :is_active])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end

  @doc "Tüm aktif odaları listeler"
  def list_active do
    __MODULE__
    |> where([r], r.is_active == true)
    |> order_by([r], r.inserted_at)
    |> Repo.all()
  end

  @doc "ID ile oda bulur"
  def get!(id), do: Repo.get!(Room, id)

  @doc "Oda oluşturur"
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end
end
