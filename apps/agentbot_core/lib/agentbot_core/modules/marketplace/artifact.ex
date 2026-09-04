defmodule AgentbotCore.Modules.Marketplace.Artifact do
  @moduledoc """
  Artifact — task'ın çıktısı. Mesaj değil, ürün.

  Conversation is temporary. Artifact is the product.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :task_id,
             :room_id,
             :produced_by,
             :artifact_type,
             :title,
             :content,
             :metadata,
             :verified,
             :verified_by,
             :verified_at,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo

  schema "artifacts" do
    belongs_to(:task, AgentbotCore.Modules.Marketplace.Task)
    belongs_to(:room, AgentbotCore.Modules.Chat.Room)
    field(:produced_by, :string)
    # report, code, diff, decision, data
    field(:artifact_type, :string)
    field(:title, :string)
    field(:content, :string)
    # JSON string
    field(:metadata, :string)
    field(:verified, :boolean, default: false)
    field(:verified_by, :string)
    field(:verified_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :task_id,
      :room_id,
      :produced_by,
      :artifact_type,
      :title,
      :content,
      :metadata,
      :verified,
      :verified_by,
      :verified_at
    ])
    |> validate_required([:task_id, :produced_by, :artifact_type, :content])
  end

  @doc "Artifact oluştur"
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Artifact doğrula ya da reddet (human/agent verification)"
  def verify(id, verified_by, verified \\ true) do
    __MODULE__
    |> Repo.get!(id)
    |> changeset(%{verified: verified, verified_by: verified_by, verified_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc "Task'ın artifact'larını listele"
  def list_by_task(task_id) do
    __MODULE__
    |> where([a], a.task_id == ^task_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc "Agent'ın ürettiği artifact'ları listele"
  def list_by_producer(agent_id) do
    __MODULE__
    |> where([a], a.produced_by == ^agent_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc "Odadaki tüm artifact'ları listele"
  def list_by_room(room_id) do
    __MODULE__
    |> where([a], a.room_id == ^room_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc "Doğrulanmamış artifact'ları listele"
  def list_unverified do
    __MODULE__
    |> where([a], a.verified == false)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end
end
