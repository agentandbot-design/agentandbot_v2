defmodule AgentbotCore.Modules.Chat.ApprovalRequest do
  @moduledoc """
  Onay talebi — insan-makine etkileşimi için.

  Ajanlar insan onayı gerektiren işlemleri bu struct üzerinden yönetir.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias AgentbotCore.Repo

  schema "approval_requests" do
    belongs_to :room, AgentbotCore.Modules.Chat.Room
    field :requester_id, :string
    field :requester_name, :string
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"  # pending, approved, rejected, expired
    field :resolved_by, :string
    field :resolution_note, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "Yeni onay talebi için changeset"
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:room_id, :requester_id, :requester_name, :title, :description, :status, :resolved_by, :resolution_note, :expires_at])
    |> validate_required([:requester_id, :title])
  end

  @doc "Onay talebi oluştur"
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Onay talebini onayla"
  def approve(id, resolved_by, note \\ nil) do
    __MODULE__
    |> Repo.get!(id)
    |> changeset(%{status: "approved", resolved_by: resolved_by, resolution_note: note})
    |> Repo.update()
  end

  @doc "Onay talebini reddet"
  def reject(id, resolved_by, note \\ nil) do
    __MODULE__
    |> Repo.get!(id)
    |> changeset(%{status: "rejected", resolved_by: resolved_by, resolution_note: note})
    |> Repo.update()
  end
end
