defmodule AgentbotCore.Modules.Marketplace.Task do
  @moduledoc """
  Task — operasyonel birim. Agent veya insanın yaptığı iş.

  Lifecycle: open → assigned → in_progress → review → completed | failed | blocked

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
  alias AgentbotCore.PubSub
  alias AgentbotCore.Repo
  alias AgentbotCore.Workers.TaskProcessor

  schema "tasks" do
    belongs_to(:room, AgentbotCore.Modules.Chat.Room)
    has_many(:artifacts, AgentbotCore.Modules.Marketplace.Artifact)

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
    result =
      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, task} ->
        broadcast_change("task_created", task)
        {:ok, task}

      error ->
        error
    end
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
        broadcast_change("task_updated", t)
        {:ok, t}

      error ->
        error
    end
  end

  @doc """
  Task'ı claim et — race condition koruması.

  Sadece status: open veya assigned olan task'lar claim edilebilir.
  Eğer task zaten başka bir agent tarafından claim edilmişse ve hala active ise
  reject edilir.
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
        result =
          task
          |> changeset(%{assigned_to: agent_id, status: "in_progress"})
          |> Repo.update()

        case result do
          {:ok, t} ->
            broadcast_change("task_updated", t)
            {:ok, t}

          error ->
            error
        end
    end
  end

  @doc """
  Task durumunu güncelle.

  Güvenlik Guard'ı: `status == "completed"` yapılırken task'a ait en az bir Artifact
  bulunması zorunludur. Force modu (`opts[:force] == true`) sadece istisnai durumlar içindir.
  """
  def update_status(task_id, status, opts \\ []) do
    task = Repo.get!(__MODULE__, task_id) |> Repo.preload(:artifacts)

    # Artifact guard kontrolü
    if status == "completed" and not Keyword.get(opts, :force, false) and Enum.empty?(task.artifacts) do
      {:error, :artifact_required}
    else
      params =
        if status in ["completed", "failed"] do
          %{status: status, completed_at: DateTime.utc_now()}
        else
          %{status: status}
        end

      result =
        task
        |> changeset(params)
        |> Repo.update()

      case result do
        {:ok, updated_task} ->
          broadcast_change("task_updated", updated_task)
          {:ok, updated_task}

        error ->
          error
      end
    end
  end

  @doc "Task sil"
  def delete(task_id) do
    task = Repo.get!(__MODULE__, task_id)
    result = Repo.delete(task)

    case result do
      {:ok, deleted} ->
        broadcast_change("task_deleted", deleted)
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc "Tüm task'ları listele (opsiyonel filtrelerle)"
  def list_all(opts \\ []) do
    query = from(t in __MODULE__, order_by: [desc: t.priority, desc: t.inserted_at])

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> from(t in query, where: t.status == ^status)
      end

    query
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "Kanban görünümü için tüm task'ları getir"
  def list_for_kanban do
    __MODULE__
    |> order_by([t], desc: t.priority, desc: t.updated_at, desc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "Capability'ye göre açık task'ları listele"
  def list_open_by_capability(capability) do
    __MODULE__
    |> where([t], t.capability == ^capability and t.status in ["open", "ready"])
    |> order_by([t], desc: t.priority, asc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "Agent'a atanmış task'ları listele"
  def list_by_agent(agent_id) do
    __MODULE__
    |> where([t], t.assigned_to == ^agent_id)
    |> order_by([t], desc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "Odadaki tüm task'ları listele"
  def list_by_room(room_id) do
    __MODULE__
    |> where([t], t.room_id == ^room_id)
    |> order_by([t], desc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "ID ile task bul"
  def get!(id), do: Repo.get!(__MODULE__, id) |> Repo.preload(:artifacts)

  defp broadcast_change(event, task) do
    PubSub.broadcast("kanban:tasks", event, %{
      id: task.id,
      title: task.title,
      status: task.status,
      assigned_to: task.assigned_to,
      capability: task.capability,
      priority: task.priority
    })
  rescue
    _ -> :ok
  end
end
