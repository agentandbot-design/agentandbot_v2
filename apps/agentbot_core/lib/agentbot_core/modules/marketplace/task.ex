defmodule AgentbotCore.Modules.Marketplace.Task do
  @moduledoc """
  Task — operasyonel birim. Agent'ın yaptığı iş.

  Lifecycle: open → assigned → in_progress → completed | failed

  Bauhaus: sadece gerekli alanlar. Chat değil, iş.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :room_id,
             :created_by,
             :assigned_to,
             :capability,
             :title,
             :description,
             :input,
             :status,
             :priority,
             :deadline_at,
             :completed_at,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo
  alias AgentbotCore.Workers.TaskProcessor

  schema "tasks" do
    belongs_to(:room, AgentbotCore.Modules.Chat.Room)
    field(:created_by, :string)
    field(:assigned_to, :string)
    field(:capability, :string)
    field(:title, :string)
    field(:description, :string)
    # JSON string — task parametreleri
    field(:input, :string)
    field(:status, :string, default: "open")
    field(:priority, :integer, default: 0)
    field(:deadline_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :room_id,
      :created_by,
      :assigned_to,
      :capability,
      :title,
      :description,
      :input,
      :status,
      :priority,
      :deadline_at,
      :completed_at
    ])
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
    task =
      __MODULE__
      |> Repo.get!(task_id)
      |> changeset(%{assigned_to: agent_id, status: "assigned"})
      |> Repo.update()

    case task do
      {:ok, t} ->
        # Oban işini kuyruğa at
        Oban.insert(TaskProcessor.new(%{task_id: t.id}))

        {:ok, t}

      error ->
        error
    end
  end

  @doc """
  Task'ı claim et — race condition koruması.

  Sadece status: open veya assigned olan task'lar claim edilebilir.
  Eğer task zaten başka bir agent tarafından claim edilmişse ve hala active ise
  reject edilir. Claims tablosu: agent_id + task_id unique.
  """
  def claim(task_id, agent_id) do
    task = Repo.get(__MODULE__, task_id)

    cond do
      task == nil ->
        {:error, :not_found}

      task.status in ["completed", "failed"] ->
        {:error, :already_done}

      task.assigned_to != nil and task.assigned_to != agent_id and task.status == "in_progress" ->
        {:error, :locked}

      true ->
        task
        |> changeset(%{assigned_to: agent_id, status: "in_progress"})
        |> Repo.update()
    end
  end

  @doc "Task durumunu güncelle"
  def update_status(task_id, status) do
    params =
      if status in ["completed", "failed"] do
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
    |> order_by([t], desc: t.priority, asc: t.inserted_at)
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
