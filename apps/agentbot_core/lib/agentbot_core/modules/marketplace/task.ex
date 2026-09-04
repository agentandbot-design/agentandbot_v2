defmodule AgentbotCore.Modules.Marketplace.Task do
  @moduledoc """
  Task — operasyonel birim. Agent veya insanın yaptığı iş.

  Lifecycle: open → assigned → in_progress → review → completed | failed | blocked
  Visibility: public (açık) | private (kapalı / takıma özel)
  Team: serbest takım adı (Örn: "Core", "Harezmi", "SAP AI", "Devops", vb.)
  Tags: serbest etiketler (Örn: "#SAP #harezm #agentandbot")
  Parent: alt görevler için parent_id desteği
  Archive: completed kartlar arşivlenebilir

  Bauhaus: sadece gerekli alanlar. Chat değil, iş.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, where: 3, order_by: 3, preload: 2, select: 3, group_by: 3]

  alias AgentbotCore.Modules.Marketplace.TaskEvent
  alias AgentbotCore.PubSub
  alias AgentbotCore.Repo
  alias AgentbotCore.Workers.TaskProcessor

  @derive {Jason.Encoder,
           only: [
             :id,
             :room_id,
             :created_by,
             :assigned_to,
             :capability,
             :team,
             :visibility,
             :tags,
             :title,
             :description,
             :input,
             :status,
             :priority,
             :parent_id,
             :archived,
             :deadline_at,
             :completed_at,
             :external_url,
             :source_type,
             :inserted_at,
             :updated_at
           ]}

  schema "tasks" do
    belongs_to(:room, AgentbotCore.Modules.Chat.Room)
    belongs_to(:parent, __MODULE__)
    has_many(:children, __MODULE__, foreign_key: :parent_id)
    has_many(:artifacts, AgentbotCore.Modules.Marketplace.Artifact)
    has_many(:comments, AgentbotCore.Modules.Marketplace.TaskComment)
    has_many(:events, AgentbotCore.Modules.Marketplace.TaskEvent)

    field(:created_by, :string)
    field(:assigned_to, :string)
    field(:capability, :string)
    field(:team, :string, default: "Core")
    field(:visibility, :string, default: "public")
    field(:tags, :string)
    field(:title, :string)
    field(:description, :string)
    field(:input, :string)
    field(:status, :string, default: "open")
    field(:priority, :integer, default: 0)
    field(:archived, :boolean, default: false)
    field(:deadline_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:external_url, :string)
    field(:source_type, :string, default: "manual")

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :room_id,
      :created_by,
      :assigned_to,
      :capability,
      :team,
      :visibility,
      :tags,
      :title,
      :description,
      :input,
      :status,
      :priority,
      :parent_id,
      :archived,
      :deadline_at,
      :completed_at,
      :external_url,
      :source_type
    ])
    |> validate_required([:created_by, :capability, :title])
  end

  @doc "Task oluştur + event kaydet"
  def create(attrs) do
    result = %__MODULE__{} |> changeset(attrs) |> Repo.insert()

    case result do
      {:ok, task} ->
        TaskEvent.log(task.id, attrs[:created_by] || "system", "created", %{
          title: task.title,
          capability: task.capability
        })

        broadcast_change("task_created", task)
        {:ok, task}

      error ->
        error
    end
  end

  @doc "Task alanlarını güncelle / düzenle + event kaydet"
  @spec update(integer() | %__MODULE__{}, map()) :: {:ok, %__MODULE__{}} | {:error, term()}
  def update(task_id, attrs) when is_integer(task_id) do
    task = Repo.get!(__MODULE__, task_id)
    update(task, attrs)
  end

  def update(%__MODULE__{} = task, attrs) do
    old_status = task.status
    result = task |> changeset(attrs) |> Repo.update()

    case result do
      {:ok, updated} ->
        changes = Map.filter(attrs, fn {k, v} -> Map.get(task, k) != v end)

        action =
          if changes[:status] && changes[:status] != old_status,
            do: "status_changed",
            else: "edited"

        TaskEvent.log(updated.id, attrs[:edited_by] || "user", action, %{
          changes: Map.keys(changes)
        })

        broadcast_change("task_updated", updated)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc "Task'ı agent'a ata + event kaydet"
  def assign(task_id, agent_id) do
    task =
      __MODULE__
      |> Repo.get!(task_id)
      |> changeset(%{assigned_to: agent_id, status: "assigned"})
      |> Repo.update()

    case task do
      {:ok, t} ->
        TaskEvent.log(t.id, agent_id, "assigned", %{agent: agent_id})
        Oban.insert(TaskProcessor.new(%{task_id: t.id}))
        broadcast_change("task_updated", t)
        {:ok, t}

      error ->
        error
    end
  end

  @doc "Task claim (race condition koruması)"
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
          task |> changeset(%{assigned_to: agent_id, status: "in_progress"}) |> Repo.update()

        case result do
          {:ok, t} ->
            TaskEvent.log(t.id, agent_id, "claimed", %{agent: agent_id})
            broadcast_change("task_updated", t)
            {:ok, t}

          error ->
            error
        end
    end
  end

  @doc "Task durumunu güncelle + artifact guard + event kaydet"
  def update_status(task_id, status, opts \\ []) do
    task = Repo.preload(Repo.get!(__MODULE__, task_id), :artifacts)

    if status == "completed" and not Keyword.get(opts, :force, false) and
         Enum.empty?(task.artifacts) do
      {:error, :artifact_required}
    else
      params =
        if status in ["completed", "failed"] do
          %{status: status, completed_at: DateTime.utc_now()}
        else
          %{status: status}
        end

      result = task |> changeset(params) |> Repo.update()

      case result do
        {:ok, updated} ->
          TaskEvent.log(updated.id, opts[:actor] || "system", "status_changed", %{
            from: task.status,
            to: status
          })

          broadcast_change("task_updated", updated)
          {:ok, updated}

        error ->
          error
      end
    end
  end

  @doc "Task'ı arşivle"
  def archive(task_id) do
    task = Repo.get!(__MODULE__, task_id)
    result = task |> changeset(%{archived: true}) |> Repo.update()

    case result do
      {:ok, t} ->
        TaskEvent.log(t.id, "system", "archived", %{})
        broadcast_change("task_archived", t)
        {:ok, t}

      error ->
        error
    end
  end

  @doc "Arşivden çıkar"
  def unarchive(task_id) do
    task = Repo.get!(__MODULE__, task_id)
    result = task |> changeset(%{archived: false}) |> Repo.update()

    case result do
      {:ok, t} ->
        TaskEvent.log(t.id, "system", "unarchived", %{})
        broadcast_change("task_updated", t)
        {:ok, t}

      error ->
        error
    end
  end

  @doc "Task sil + event kaydet"
  def delete(task_id) do
    task = Repo.get!(__MODULE__, task_id)
    TaskEvent.log(task.id, "system", "deleted", %{title: task.title})
    result = Repo.delete(task)

    case result do
      {:ok, deleted} ->
        broadcast_change("task_deleted", deleted)
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc "Tüm task'ları listele (arsivlenmemiş)"
  def list_all(opts \\ []) do
    query =
      from(t in __MODULE__,
        where: t.archived == false,
        order_by: [desc: t.priority, desc: t.inserted_at]
      )

    query = apply_filters(query, opts)
    query |> preload([:artifacts, :comments, :children]) |> Repo.all()
  end

  @doc "Kanban görünümü için tüm task'ları getir (arsivlenmemiş)"
  def list_for_kanban(opts \\ []) do
    query =
      from(t in __MODULE__,
        where: t.archived == false,
        order_by: [desc: t.priority, desc: t.updated_at, desc: t.inserted_at]
      )

    query = apply_filters(query, opts)
    query |> preload([:artifacts, :comments, :children]) |> Repo.all()
  end

  @doc "Arşivlenmiş task'ları listele"
  def list_archived(opts \\ []) do
    query = from(t in __MODULE__, where: t.archived == true, order_by: [desc: t.completed_at])
    query = apply_filters(query, opts)
    query |> preload(:artifacts) |> Repo.all()
  end

  @doc "Çocuk task'ları getir"
  def list_children(parent_id) do
    __MODULE__
    |> where([t], t.parent_id == ^parent_id)
    |> order_by([t], desc: t.priority, asc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @doc "Kullanıcının iş yükünü say"
  def workload_counts do
    __MODULE__
    |> where(
      [t],
      t.archived == false and t.status in ["open", "ready", "assigned", "in_progress"]
    )
    |> select([t], %{assignee: t.assigned_to, count: count(t.id)})
    |> group_by([t], t.assigned_to)
    |> Repo.all()
  end

  @doc "Mevcut tüm benzersiz takım isimlerini getirir (dinamik takım filtresi için)"
  def list_distinct_teams do
    from(t in __MODULE__,
      select: t.team,
      distinct: true,
      where: not is_nil(t.team) and t.team != ""
    )
    |> Repo.all()
    |> Enum.sort()
  end

  @doc "Etiket string'ini temizlenmiş liste haline getirir (['SAP', 'harezm'])"
  def parse_tag_list(nil), do: []

  def parse_tag_list(tags_str) when is_binary(tags_str) do
    tags_str
    |> String.split([",", " ", "\n", "\t"], trim: true)
    |> Enum.map(fn tag -> tag |> String.trim_leading("#") |> String.trim() end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  @doc "Tags string'i içinde #git veya #not varsa external URL üretir"
  def external_link_from_tags(title, tags_str) do
    tags = parse_tag_list(tags_str)

    cond do
      "git" in tags ->
        {"github", github_url_from_title(title)}

      "not" in tags ->
        {"gdrive", nil}

      true ->
        {"manual", nil}
    end
  end

  # Başlıktan slug üreterek varsayılan GitHub dosya URL'i
  defp github_url_from_title(title) do
    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^\w\s\-]/u, "")
      |> String.replace(~r/\s+/u, "-")
      |> String.slice(0, 50)

    "https://github.com/agentandbot-design/agentandbot_v2/blob/main/notes/#{slug}.md"
  end

  defp apply_filters(query, opts) do
    query
    |> maybe_filter(:status, opts[:status])
    |> maybe_filter(:team, opts[:team])
    |> maybe_filter(:visibility, opts[:visibility])
    |> maybe_filter(:room_id, opts[:room_id])
  end

  defp maybe_filter(query, _key, nil), do: query
  defp maybe_filter(query, _key, "all"), do: query
  defp maybe_filter(query, :status, status), do: from(t in query, where: t.status == ^status)
  defp maybe_filter(query, :team, team), do: from(t in query, where: t.team == ^team)
  defp maybe_filter(query, :visibility, vis), do: from(t in query, where: t.visibility == ^vis)

  defp maybe_filter(query, :room_id, rid) when is_integer(rid),
    do: from(t in query, where: t.room_id == ^rid)

  @doc "Capability'ye göre açık task'ları listele"
  def list_open_by_capability(capability) do
    __MODULE__
    |> where(
      [t],
      t.capability == ^capability and t.status in ["open", "ready"] and t.archived == false
    )
    |> order_by([t], desc: t.priority, asc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  def list_by_agent(agent_id) do
    __MODULE__
    |> where([t], t.assigned_to == ^agent_id and t.archived == false)
    |> order_by([t], desc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  def list_by_room(room_id) do
    __MODULE__
    |> where([t], t.room_id == ^room_id and t.archived == false)
    |> order_by([t], desc: t.inserted_at)
    |> preload(:artifacts)
    |> Repo.all()
  end

  @spec get!(integer()) :: %__MODULE__{}
  def get!(id) do
    Repo.preload(Repo.get!(__MODULE__, id), [:artifacts, :comments, :children])
  end

  defp broadcast_change(event, task) do
    PubSub.broadcast("kanban:tasks", event, %{
      id: task.id,
      title: task.title,
      status: task.status,
      team: task.team,
      visibility: task.visibility,
      tags: task.tags,
      assigned_to: task.assigned_to,
      capability: task.capability,
      priority: task.priority
    })
  rescue
    _ -> :ok
  end
end
