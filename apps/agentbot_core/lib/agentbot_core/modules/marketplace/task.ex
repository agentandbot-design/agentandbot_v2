defmodule AgentbotCore.Modules.Marketplace.Task do
  @moduledoc """
  Task — operasyonel birim. Agent'ın yaptığı iş.

  Lifecycle: open → assigned → in_progress → completed | failed

  Bauhaus: sadece gerekli alanlar. Chat değil, iş.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :room_id, :created_by, :assigned_to, :capability, :title, :description, :input, :status, :priority, :deadline_at, :completed_at, :inserted_at, :updated_at]}
  alias AgentbotCore.Repo

  schema "tasks" do
    belongs_to :room, AgentbotCore.Modules.Chat.Room
    field :created_by, :string
    field :assigned_to, :string
    field :capability, :string
    field :title, :string
    field :description, :string
    field :input, :string          # JSON string — task parametreleri
    field :status, :string, default: "open"
    field :priority, :integer, default: 0
    field :deadline_at, :utc_datetime
    field :completed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:room_id, :created_by, :assigned_to, :capability, :title, :description, :input, :status, :priority, :deadline_at, :completed_at])
    |> validate_required([:created_by, :capability, :title])
  end

  @doc "Task oluştur"
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Task'ı agent'a ata"
  def assign(task_id, agent_id) do
    __MODULE__
    |> Repo.get!(task_id)
    |> changeset(%{assigned_to: agent_id, status: "assigned"})
    |> Repo.update()
  end

  @doc "Task durumunu güncelle"
  def update_status(task_id, status) do
    params = if status in ["completed", "failed"] do
      %{status: status, completed_at: DateTime.utc_now()}
    else
      %{status: status}
    end

    __MODULE__
    |> Repo.get!(task_id)
    |> changeset(params)
    |> Repo.update()
  end

  @doc "Capability'ye göre açık task'ları listele"
  def list_open_by_capability(capability) do
    __MODULE__
    |> where([t], t.capability == ^capability and t.status == "open")
    |> order_by([t], [desc: t.priority, asc: t.inserted_at])
    |> Repo.all()
  end

  @doc "Agent'a atanmış task'ları listele"
  def list_by_agent(agent_id) do
    __MODULE__
    |> where([t], t.assigned_to == ^agent_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc "Odadaki tüm task'ları listele"
  def list_by_room(room_id) do
    __MODULE__
    |> where([t], t.room_id == ^room_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc "ID ile task bul"
  def get!(id), do: Repo.get!(__MODULE__, id)
end
