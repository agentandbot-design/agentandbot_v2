defmodule AgentbotWeb.KanbanLive do
  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.Room
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.PubSub
  alias AgentbotCore.Repo
  import Ecto.Query

  @stages ["triage", "todo", "scheduled", "ready", "running", "blocked", "done"]

  @stage_labels %{
    "triage" => "Triage",
    "todo" => "Todo",
    "scheduled" => "Scheduled",
    "ready" => "Ready",
    "running" => "Running",
    "blocked" => "Blocked",
    "done" => "Done"
  }

  @stage_emojis %{
    "triage" => "📥",
    "todo" => "📋",
    "scheduled" => "📅",
    "ready" => "🚀",
    "running" => "⚡",
    "blocked" => "🚫",
    "done" => "✅"
  }

  # Mevcut task statülerini 7 aşamaya map et (DB status → kanban aşaması, görüntüleme)
  @status_map %{
    "open" => "triage",
    "in_progress" => "running",
    "completed" => "done",
    "blocked" => "blocked",
    "triage" => "triage",
    "todo" => "todo",
    "scheduled" => "scheduled",
    "ready" => "ready",
    "running" => "running",
    "done" => "done"
  }

  # Kanban aşaması → gerçek Task DB status'ü (yazma yönü)
  @kanban_to_status %{
    "triage" => "open",
    "running" => "in_progress",
    "done" => "completed",
    "todo" => "todo",
    "scheduled" => "scheduled",
    "ready" => "ready",
    "blocked" => "blocked"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe("kanban:updates")
      PubSub.subscribe("tasks:updates")
    end

    {:ok,
     socket
     |> assign(:page_title, "Kanban Board")
     |> assign(:rooms, [])
     |> assign(:tasks, [])
     |> assign(:tasks_by_room, %{})
     |> assign(:filter_room, "all")
     |> assign(:filter_stage, "all")
     |> assign(:filter_assignee, "all")
     |> assign(:collapsed, %{})
     |> assign(:stages, @stages)
     |> assign(:stage_labels, @stage_labels)
     |> assign(:stage_emojis, @stage_emojis)
     |> assign(:moving_task, nil)
     |> assign(:new_task_title, "")
     |> assign(:new_task_room, "9")
     |> load_data()}
  end

  @impl true
  def handle_params(%{"room_id" => room_id}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filter_room, room_id)
     |> assign(:new_task_room, room_id)
     |> load_data()}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_section", %{"room_id" => room_id}, socket) do
    collapsed = socket.assigns.collapsed
    new_val = not Map.get(collapsed, room_id, false)
    {:noreply, assign(socket, :collapsed, Map.put(collapsed, room_id, new_val))}
  end

  def handle_event("filter_room", %{"room" => room}, socket) do
    {:noreply, load_data(assign(socket, filter_room: room))}
  end

  def handle_event("filter_stage", %{"stage" => stage}, socket) do
    {:noreply, assign(socket, :filter_stage, stage)}
  end

  def handle_event("filter_assignee", %{"assignee" => assignee}, socket) do
    {:noreply, assign(socket, :filter_assignee, assignee)}
  end

  def handle_event("start_move", %{"task_id" => task_id}, socket) do
    {:noreply, assign(socket, :moving_task, task_id)}
  end

  def handle_event("drop_task", %{"task_id" => task_id, "stage" => stage}, socket) do
    db_status = Map.get(@kanban_to_status, stage, stage)

    res =
      case Repo.get(Task, task_id) do
        nil -> {:error, :not_found}
        _task -> Task.update_status(task_id, db_status)
      end

    {:noreply,
     socket
     |> maybe_flash_move_error(res)
     |> assign(:moving_task, nil)
     |> load_data()}
  end

  def handle_event("drop_task", _params, socket) do
    {:noreply, assign(socket, :moving_task, nil)}
  end

  def handle_event("update_stage", %{"task_id" => task_id, "stage" => stage}, socket) do
    db_status = Map.get(@kanban_to_status, stage, stage)

    res =
      case Repo.get(Task, task_id) do
        nil -> {:error, :not_found}
        _task -> Task.update_status(task_id, db_status)
      end

    {:noreply, socket |> maybe_flash_move_error(res) |> load_data()}
  end

  def handle_event("create_task", %{"title" => title, "room_id" => room_id}, socket) do
    trimmed = String.trim(title)

    if trimmed != "" do
      %Task{}
      |> Task.changeset(%{
        title: trimmed,
        room_id: String.to_integer(room_id),
        status: "open",
        created_by: "user",
        source_type: "manual"
      })
      |> Repo.insert()
    end

    {:noreply,
     socket
     |> assign(:new_task_title, "")
     |> load_data()}
  end

  def handle_event("update_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :new_task_title, title)}
  end

  def handle_event("update_new_room", %{"room_id" => room_id}, socket) do
    {:noreply, assign(socket, :new_task_room, room_id)}
  end

  def handle_event("delete_task", %{"task_id" => task_id}, socket) do
    case Repo.get(Task, task_id) do
      nil -> :ok
      task -> Repo.update(Task.changeset(task, %{archived: true}))
    end

    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_info({:task_updated, _task}, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_info({:task_created, _task}, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp load_data(socket) do
    rooms = Enum.filter(Repo.all(Room), & &1.is_active)
    filter_room = socket.assigns.filter_room
    filter_assignee = socket.assigns.filter_assignee

    base_query =
      from(t in Task,
        where: t.archived == false or is_nil(t.archived),
        order_by: [desc: t.priority, asc: t.inserted_at]
      )

    tasks =
      base_query
      |> then(fn q ->
        case filter_room do
          "all" -> q
          id -> from(t in q, where: t.room_id == ^id)
        end
      end)
      |> Repo.all()
      |> Enum.map(fn t -> %{t | status: normalize_status(t.status)} end)
      |> maybe_filter_assignee(filter_assignee)

    tasks_by_room = Enum.group_by(tasks, fn t -> to_string(t.room_id) end)

    unique_assignees = unique_assignees(tasks)

    socket
    |> assign(:rooms, rooms)
    |> assign(:tasks, tasks)
    |> assign(:tasks_by_room, tasks_by_room)
    |> assign(:unique_assignees, unique_assignees)
  end

  defp normalize_status(status) when status in @stages, do: status
  defp normalize_status(status), do: Map.get(@status_map, status, "triage")

  defp maybe_flash_move_error(socket, {:ok, _task}), do: socket

  defp maybe_flash_move_error(socket, {:error, :artifact_required}) do
    put_flash(
      socket,
      :error,
      "Artifact zorunludur: Task'ı 'done' yapmadan önce artifact üretilmelidir."
    )
  end

  defp maybe_flash_move_error(socket, {:error, :not_found}) do
    put_flash(socket, :error, "Task bulunamadı.")
  end

  defp maybe_flash_move_error(socket, _), do: socket

  defp maybe_filter_assignee(tasks, "all"), do: tasks

  defp maybe_filter_assignee(tasks, "unassigned") do
    Enum.reject(tasks, fn t -> t.assigned_to != nil and t.assigned_to != "" end)
  end

  defp maybe_filter_assignee(tasks, assignee) do
    Enum.filter(tasks, fn t -> t.assigned_to == assignee end)
  end

  defp unique_assignees(tasks) do
    tasks
    |> Enum.map(& &1.assigned_to)
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp column_border_class("triage"), do: "border-purple-500/50 bg-purple-500/5"
  defp column_border_class("todo"), do: "border-blue-500/50 bg-blue-500/5"
  defp column_border_class("scheduled"), do: "border-amber-500/50 bg-amber-500/5"
  defp column_border_class("ready"), do: "border-cyan-500/50 bg-cyan-500/5"
  defp column_border_class("running"), do: "border-green-500/50 bg-green-500/5"
  defp column_border_class("blocked"), do: "border-red-500/50 bg-red-500/5"
  defp column_border_class("done"), do: "border-neutral-500/50 bg-neutral-500/5"

  defp card_border_class("triage"), do: "border-purple-500/30 bg-purple-500/5"
  defp card_border_class("todo"), do: "border-blue-500/30 bg-blue-500/5"
  defp card_border_class("scheduled"), do: "border-amber-500/30 bg-amber-500/5"
  defp card_border_class("ready"), do: "border-cyan-500/30 bg-cyan-500/5"
  defp card_border_class("running"), do: "border-green-500/30 bg-green-500/5"
  defp card_border_class("blocked"), do: "border-red-500/30 bg-red-500/5"
  defp card_border_class("done"), do: "border-neutral-500/30 bg-neutral-500/5"

  defp priority_color(priority) do
    cond do
      priority >= 10 -> "text-red-400"
      priority >= 5 -> "text-amber-400"
      priority >= 1 -> "text-blue-400"
      true -> "text-neutral-500"
    end
  end

  defp relative_time(nil), do: ""

  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "şimdi"
      diff < 60 -> "#{diff}dk"
      diff < 1440 -> "#{div(diff, 60)}s"
      diff < 10_080 -> "#{div(diff, 1440)}g"
      true -> "#{div(diff, 10_080)}hft"
    end
  end

  defp assignee_initial(nil), do: "?"
  defp assignee_initial(""), do: "?"

  defp assignee_initial(name) do
    name
    |> String.split(~r/[-_ ]/, trim: true)
    |> List.first()
    |> String.slice(0, 1)
    |> String.upcase()
  end

  # Assignee adına sabit bir renk atamak için hash kullan
  defp assignee_color(nil), do: "bg-neutral-700 text-neutral-300"

  defp assignee_color(name) do
    palette = [
      "bg-indigo-600 text-white",
      "bg-emerald-600 text-white",
      "bg-rose-600 text-white",
      "bg-sky-600 text-white",
      "bg-orange-600 text-white",
      "bg-violet-600 text-white",
      "bg-teal-600 text-white",
      "bg-pink-600 text-white"
    ]

    index = rem(:erlang.phash2(name), length(palette))
    Enum.at(palette, index)
  end

  defp done?("done"), do: true
  defp done?(_), do: false

  defp assigned_class(nil), do: "italic"
  defp assigned_class(""), do: "italic"
  defp assigned_class(_), do: ""

  defp title_class(status) do
    if done?(status), do: "line-through text-neutral-500", else: "text-white"
  end

  defp column_dot_class("triage"), do: "bg-purple-400"
  defp column_dot_class("todo"), do: "bg-blue-400"
  defp column_dot_class("scheduled"), do: "bg-amber-400"
  defp column_dot_class("ready"), do: "bg-cyan-400"
  defp column_dot_class("running"), do: "bg-green-400"
  defp column_dot_class("blocked"), do: "bg-red-400"
  defp column_dot_class("done"), do: "bg-neutral-400"

  defp priority_label(priority) do
    cond do
      priority >= 10 -> "Yüksek"
      priority >= 5 -> "Orta"
      priority >= 1 -> "Düşük"
      true -> ""
    end
  end
end
