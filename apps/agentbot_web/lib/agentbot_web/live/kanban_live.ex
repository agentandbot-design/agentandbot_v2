defmodule AgentbotWeb.KanbanLive do
  @moduledoc """
  KanbanLive — AgentAndBot Özel Kanban Görev ve Problem Takip Panosu.

  Takımlar için Açık (Public) veya Kapalı (Private/Takıma Özel) çalışma desteği.
  Hızlı düzenleme, tek tıkla durum/takım/görünürlük geçişleri ve gerçek zamanlı senkronizasyon.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.Message
  alias AgentbotCore.Modules.Chat.Room
  alias AgentbotCore.Modules.Marketplace.Artifact
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Marketplace.TaskComment
  alias AgentbotCore.Modules.Marketplace.TaskEvent
  alias AgentbotCore.PubSub
  alias AgentbotCore.Repo

  @columns [
    %{id: "open", title: "Açık / Backlog", icon: "📥", badge: "ab-badge--info"},
    %{id: "in_progress", title: "Sürüyor", icon: "⚙️", badge: "ab-badge--warn"},
    %{id: "review", title: "İnceleme / Test", icon: "🔍", badge: "ab-badge--warn"},
    %{id: "completed", title: "Tamamlandı", icon: "✅", badge: "ab-badge--ok"},
    %{id: "blocked", title: "Engelli / İptal", icon: "⛔", badge: "ab-badge--err"}
  ]

  @capabilities [
    {"Bug & Hata Düzeltme", "bugfix"},
    {"Özellik Geliştirme", "feature"},
    {"Kod İnceleme & Güvenlik", "code.review"},
    {"Haber / Feed Sistemi", "newsfeed"},
    {"Kanban & İş Akışı", "kanban"},
    {"Altyapı & Devops", "infra"},
    {"Hafıza & Entegrasyon", "memory"},
    {"Genel / Diğer", "general"}
  ]

  @teams [
    {"Çekirdek Ekip (Core)", "core"},
    {"Yapay Zeka & Ajanlar (Agents)", "agents"},
    {"Güvenlik Takımı (Security)", "security"},
    {"Altyapı & Devops (Infra)", "infra"},
    {"Tasarım & UI (Design)", "design"},
    {"Genel (General)", "general"}
  ]

  @visibilities [
    {"🌐 Açık (Public)", "public"},
    {"🔒 Kapalı / Takıma Özel (Private)", "private"}
  ]

  @assignees [
    {"Hermes Agent (Yerel)", "hermes-local"},
    {"Sara (Güvenlik / Review)", "sara"},
    {"OpenCode (Geliştirici)", "opencode"},
    {"İlker (İnsan)", "ilkerkaan"},
    {"Atanmamış", ""}
  ]

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe("kanban:tasks")
    end

    {room_id, room} =
      case params do
        %{"id" => id_str} ->
          case Integer.parse(id_str) do
            {id, _} ->
              case Repo.get(Room, id) do
                nil -> {nil, nil}
                room -> {id, room}
              end

            _ ->
              {nil, nil}
          end

        _ ->
          {nil, nil}
      end

    socket =
      socket
      |> assign(:page_title, page_title(room))
      |> assign(:room_id, room_id)
      |> assign(:room, room)
      |> assign(:columns, @columns)
      |> assign(:capabilities, @capabilities)
      |> assign(:teams, @teams)
      |> assign(:visibilities, @visibilities)
      |> assign(:assignees, @assignees)
      |> assign(:filter_team, "all")
      |> assign(:filter_visibility, "all")
      |> assign(:filter_assignee, "all")
      |> assign(:filter_capability, "all")
      |> assign(:filter_tag, "all")
      |> assign(:search_query, "")
      |> assign(:show_modal, false)
      |> assign(:show_edit_modal, false)
      |> assign(:editing_task, nil)
      |> assign(:show_artifact_modal, nil)
      |> assign(:show_archive, false)
      |> assign(:show_detail_modal, false)
      |> assign(:detail_task, nil)
      |> assign(:detail_comments, [])
      |> assign(:detail_events, [])
      |> assign(:detail_children, [])
      |> assign(:view_mode, "kanban")
      |> assign(:calendar_tasks, [])
      |> assign(:calendar_month, Date.utc_today())
      |> assign(:chat_messages, [])
      |> assign(:chat_input, "")
      |> assign(:new_task, %{
        "title" => "",
        "description" => "",
        "capability" => "bugfix",
        "team" => "Core",
        "tags" => "",
        "visibility" => "public",
        "priority" => "1",
        "assigned_to" => "hermes-local",
        "deadline" => "",
        "room_id" => room_id
      })
      |> assign(:new_comment, %{"author" => "ilkerkaan", "body" => ""})
      |> assign(:new_subtask, %{"title" => "", "assigned_to" => "hermes-local"})
      |> assign_tasks()

    if connected?(socket) && room_id do
      AgentbotCore.PubSub.subscribe("room:#{room_id}")
    end

    {:ok, socket}
  end

  defp page_title(nil), do: "Kanban Board"
  defp page_title(room), do: "📋 #{room.name} — Kanban"

  @impl true
  def handle_event("toggle_view", _params, socket) do
    new_mode =
      case socket.assigns.view_mode do
        "kanban" -> "calendar"
        "calendar" -> "chat"
        _ -> "kanban"
      end

    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"body" => body}}, socket) do
    room_id = socket.assigns[:room_id]

    if room_id && String.trim(body) != "" do
      case Message.create(%{
             room_id: room_id,
             content: String.trim(body),
             sender_name: "İnsan",
             sender_id: "human"
           }) do
        {:ok, msg} ->
          AgentbotCore.PubSub.broadcast("room:#{room_id}", {:new_message, msg})
          {:noreply, assign(socket, :chat_input, "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Mesaj gönderilemedi.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    task = Task.get!(String.to_integer(id))

    editing_task = %{
      "id" => task.id,
      "title" => task.title || "",
      "description" => task.description || "",
      "capability" => task.capability || "general",
      "team" => task.team || "Core",
      "tags" => task.tags || "",
      "visibility" => task.visibility || "public",
      "priority" => to_string(task.priority || 0),
      "assigned_to" => task.assigned_to || "",
      "status" => task.status || "open",
      "deadline" => format_date_input(task.deadline_at)
    }

    {:noreply,
     socket
     |> assign(:editing_task, editing_task)
     |> assign(:show_edit_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:show_edit_modal, false)
     |> assign(:editing_task, nil)
     |> assign(:show_artifact_modal, nil)}
  end

  @impl true
  def handle_event("save_new_task", %{"task" => params}, socket) do
    priority = parse_int(params["priority"], 1)
    assigned_to = if params["assigned_to"] == "", do: nil, else: params["assigned_to"]
    status = if is_nil(assigned_to), do: "open", else: "assigned"

    deadline_at = build_deadline_at(params["deadline"])

    attrs = %{
      title: String.trim(params["title"] || ""),
      description: String.trim(params["description"] || ""),
      capability: params["capability"] || "general",
      team: normalize_team(params["team"]),
      tags: String.trim(params["tags"] || ""),
      visibility: params["visibility"] || "public",
      priority: priority,
      assigned_to: assigned_to,
      created_by: "ilkerkaan",
      room_id: socket.assigns[:room_id],
      status: status
    }

    attrs =
      if deadline_at, do: Map.put(attrs, :deadline_at, deadline_at), else: attrs

    if attrs.title != "" do
      case Task.create(attrs) do
        {:ok, _task} ->
          {:noreply,
           socket
           |> assign(:show_modal, false)
           |> assign(:new_task, %{
             "title" => "",
             "description" => "",
             "capability" => "bugfix",
             "team" => "Core",
             "tags" => "",
             "visibility" => "public",
             "priority" => "1",
             "assigned_to" => "hermes-local",
             "deadline" => ""
           })
           |> assign_tasks()
           |> put_flash(:info, "Yeni kart başarıyla eklendi.")}

        {:error, _changeset} ->
          {:noreply,
           put_flash(socket, :error, "Kart kaydedilemedi. Lütfen alanları kontrol edin.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Kart başlığı zorunludur.")}
    end
  end

  @impl true
  def handle_event("update_existing_task", %{"task" => params}, socket) do
    task_id = String.to_integer(params["id"])
    priority = parse_int(params["priority"], 0)
    assigned_to = if params["assigned_to"] == "", do: nil, else: params["assigned_to"]

    deadline_at = build_deadline_at(params["deadline"])

    attrs = %{
      title: String.trim(params["title"] || ""),
      description: String.trim(params["description"] || ""),
      capability: params["capability"] || "general",
      team: normalize_team(params["team"]),
      tags: String.trim(params["tags"] || ""),
      visibility: params["visibility"] || "public",
      priority: priority,
      assigned_to: assigned_to,
      status: params["status"] || "open"
    }

    attrs =
      if deadline_at, do: Map.put(attrs, :deadline_at, deadline_at), else: attrs

    if attrs.title != "" do
      case Task.update(task_id, attrs) do
        {:ok, _task} ->
          {:noreply,
           socket
           |> assign(:show_edit_modal, false)
           |> assign(:editing_task, nil)
           |> assign_tasks()
           |> put_flash(:info, "Kart başarıyla güncellendi.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Güncelleme başarısız.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Kart başlığı boş olamaz.")}
    end
  end

  @impl true
  def handle_event("toggle_visibility", %{"id" => id}, socket) do
    task = Task.get!(String.to_integer(id))
    new_vis = if task.visibility == "private", do: "public", else: "private"

    case Task.update(task, %{visibility: new_vis}) do
      {:ok, _} ->
        label = if new_vis == "private", do: "🔒 Kapalı (Takıma Özel)", else: "🌐 Açık (Public)"
        {:noreply, socket |> assign_tasks() |> put_flash(:info, "Görünürlük #{label} yapıldı.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Görünürlük değiştirilemedi.")}
    end
  end

  @impl true
  def handle_event("move_status", %{"id" => id, "status" => target_status} = params, socket) do
    task_id = String.to_integer(id)
    force = params["force"] == "true"

    case Task.update_status(task_id, target_status, force: force) do
      {:ok, _task} ->
        {:noreply, assign_tasks(socket)}

      {:error, :artifact_required} ->
        {:noreply,
         socket
         |> assign(:show_artifact_modal, task_id)
         |> put_flash(:error, "Tamamlanabilmesi için önce bir Artifact üretilmiş olmalıdır.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Durum güncellenemedi.")}
    end
  end

  @impl true
  def handle_event(
        "move_task_to",
        %{"id" => id, "target_column" => target_column} = params,
        socket
      ) do
    task_id = String.to_integer(id)
    force = params["force"] == "true"

    case Task.update_status(task_id, target_column, force: force, actor: "drag-drop") do
      {:ok, _task} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> put_flash(:info, "Kart sürüklenerek taşındı → #{target_column}")}

      {:error, :artifact_required} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> assign(:show_artifact_modal, task_id)
         |> put_flash(:error, "Tamamlanabilmesi için önce bir Artifact üretilmiş olmalıdır.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> put_flash(:error, "Sürükle bırak başarısız.")}
    end
  end

  @impl true
  def handle_event("open_artifact_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :show_artifact_modal, String.to_integer(id))}
  end

  @impl true
  def handle_event(
        "submit_artifact_and_complete",
        %{"artifact" => params, "task_id" => task_id_str},
        socket
      ) do
    task_id = String.to_integer(task_id_str)
    task = Task.get!(task_id)

    artifact_attrs = %{
      task_id: task_id,
      produced_by: task.assigned_to || "hermes-local",
      artifact_type: params["artifact_type"] || "report",
      title: params["title"] || "#{task.title} - Teslimat",
      content: params["content"] || "Görev tamamlandı ve doğrulandı.",
      verified: true,
      verified_by: "ilkerkaan",
      verified_at: DateTime.utc_now()
    }

    case Artifact.create(artifact_attrs) do
      {:ok, _artifact} ->
        Task.update_status(task_id, "completed", force: true)

        {:noreply,
         socket
         |> assign(:show_artifact_modal, nil)
         |> assign_tasks()
         |> put_flash(:info, "Artifact kaydedildi ve task tamamlandı.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Artifact oluşturulamadı.")}
    end
  end

  @impl true
  def handle_event("delete_task", %{"id" => id}, socket) do
    task_id = String.to_integer(id)

    case Task.delete(task_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> put_flash(:info, "Kart silindi.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kart silinemedi.")}
    end
  end

  @impl true
  def handle_event("archive_task", %{"id" => id}, socket) do
    task_id = String.to_integer(id)

    case Task.archive(task_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> put_flash(:info, "Kart arşive taşındı.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Kart arşive taşınamadı.")}
    end
  end

  @impl true
  def handle_event("unarchive_task", %{"id" => id}, socket) do
    task_id = String.to_integer(id)

    case Task.unarchive(task_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_tasks()
         |> put_flash(:info, "Kart arşivden geri alındı.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Geri alma başarısız.")}
    end
  end

  @impl true
  def handle_event("toggle_archive", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_archive, !socket.assigns.show_archive)
     |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_team", %{"team" => val}, socket) do
    {:noreply, socket |> assign(:filter_team, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_visibility", %{"visibility" => val}, socket) do
    {:noreply, socket |> assign(:filter_visibility, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_assignee", %{"assignee" => val}, socket) do
    {:noreply, socket |> assign(:filter_assignee, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_capability", %{"capability" => val}, socket) do
    {:noreply, socket |> assign(:filter_capability, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    {:noreply, socket |> assign(:filter_tag, tag) |> assign_tasks()}
  end

  @impl true
  def handle_event("clear_tag_filter", _params, socket) do
    {:noreply, socket |> assign(:filter_tag, "all") |> assign_tasks()}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> assign_tasks()}
  end

  # ---- Detay Modalı (Kart Detayı) ----
  @impl true
  def handle_event("open_detail", %{"id" => id}, socket) do
    {:noreply, load_detail(socket, String.to_integer(id))}
  end

  @impl true
  def handle_event("close_detail", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_detail_modal, false)
     |> assign(:detail_task, nil)
     |> assign(:detail_comments, [])
     |> assign(:detail_events, [])
     |> assign(:detail_children, [])}
  end

  # ---- Yorum Ekleme ----
  @impl true
  def handle_event("add_comment", %{"task_id" => tid, "author" => author, "body" => body}, socket) do
    task_id = String.to_integer(tid)
    author = if author in [nil, ""], do: "ilkerkaan", else: author

    case TaskComment.create(%{task_id: task_id, author: author, body: body}) do
      {:ok, _c} ->
        TaskEvent.log(task_id, author, "commented", %{length: String.length(body || "")})
        {:noreply, socket |> load_detail(task_id) |> put_flash(:info, "Yorum eklendi.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Yorum kaydedilemedi.")}
    end
  end

  # ---- Alt Görev Ekleme & Toggle ----
  @impl true
  def handle_event(
        "add_subtask",
        %{"parent_id" => pid, "title" => title, "assigned_to" => at},
        socket
      ) do
    parent_id = String.to_integer(pid)
    title = String.trim(title || "")

    if title != "" do
      parent = Task.get!(parent_id)

      attrs = %{
        title: title,
        description: "",
        capability: parent.capability || "general",
        team: parent.team || "Core",
        visibility: parent.visibility || "public",
        priority: 1,
        assigned_to: (at != "" && at) || nil,
        created_by: "ilkerkaan",
        status: "open",
        parent_id: parent_id
      }

      case Task.create(attrs) do
        {:ok, _child} ->
          TaskEvent.log(parent_id, at || "ilkerkaan", "subtask_added", %{title: title})
          {:noreply, socket |> load_detail(parent_id) |> put_flash(:info, "Alt görev eklendi.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Alt görev oluşturulamadı.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Alt görev başlığı boş olamaz.")}
    end
  end

  @impl true
  def handle_event("toggle_subtask", %{"id" => id, "parent_id" => parent_id}, socket) do
    child = Task.get!(String.to_integer(id))
    new_status = if child.status in ["open", "assigned", "ready"], do: "in_progress", else: "open"

    case Task.update_status(child.id, new_status) do
      {:ok, _} ->
        TaskEvent.log(child.id, "ilkerkaan", "status_changed", %{to: new_status})
        pid = String.to_integer(parent_id)
        {:noreply, load_detail(socket, pid)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Alt görev durumu güncellenemedi.")}
    end
  end

  # ---- PubSub Realtime ----
  @impl true
  def handle_info({:new_message, msg}, socket) do
    if socket.assigns[:room_id] == msg.room_id do
      {:noreply,
       assign(socket, :chat_messages, Enum.take(socket.assigns.chat_messages ++ [msg], 100))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:task_updated, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info({:task_created, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info({:task_deleted, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info({:task_archived, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info(_other, socket), do: {:noreply, socket}

  # ---- Private Helpers ----
  defp load_detail(socket, task_id) do
    task = Task.get!(task_id)
    comments = TaskComment.list_by_task(task_id)
    events = TaskEvent.list_by_task(task_id)
    children = Task.list_children(task_id)

    socket
    |> assign(:show_detail_modal, true)
    |> assign(:detail_task, task)
    |> assign(:detail_comments, comments)
    |> assign(:detail_events, events)
    |> assign(:detail_children, children)
  end

  defp assign_tasks(socket) do
    room_id = socket.assigns[:room_id]
    all_tasks = if room_id, do: Task.list_by_room(room_id), else: Task.list_for_kanban()

    all_teams = list_teams()
    workload = list_workload()
    filtered_tasks = filter_tasks(all_tasks, socket.assigns)
    tasks_by_column = group_by_column(filtered_tasks)
    archived_tasks = if socket.assigns[:show_archive], do: safe_list_archived(), else: []
    chat_messages = if room_id, do: Message.list_by_room(room_id, 50), else: []

    socket =
      socket
      |> assign(:stats, task_stats(all_tasks))
      |> assign(:tasks_by_column, tasks_by_column)
      |> assign(:all_teams, all_teams)
      |> assign(:calendar_tasks, filtered_tasks)
      |> assign(:calendar_month, Date.utc_today())
      |> assign(:chat_messages, chat_messages)
      |> assign(:workload, workload)
      |> assign(:archived_tasks, archived_tasks)

    reload_detail(socket)
  end

  defp list_teams do
    case safe_list_distinct_teams() do
      list when is_list(list) and list != [] -> list
      _ -> Enum.map(@teams, fn {_, id} -> id end)
    end
  end

  defp list_workload do
    case safe_workload_counts() do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp reload_detail(socket) do
    case socket.assigns[:detail_task] do
      nil ->
        socket

      %{id: id} ->
        try do
          load_detail(socket, id)
        rescue
          _ -> assign(socket, :show_detail_modal, false)
        end
    end
  end

  # Filtre koşulları — her biri bağımsız predicate
  defp filter_tasks(tasks, assigns) do
    Enum.filter(tasks, fn t ->
      match_team?(t, assigns[:filter_team] || "all") and
        match_visibility?(t, assigns[:filter_visibility] || "all") and
        match_assignee?(t, assigns[:filter_assignee] || "all") and
        match_capability?(t, assigns[:filter_capability] || "all") and
        match_tag?(t, assigns[:filter_tag] || "all") and
        match_query?(t, String.downcase(String.trim(assigns[:search_query] || "")))
    end)
  end

  defp match_team?(_t, "all"), do: true
  defp match_team?(t, val), do: (t.team || "Core") == val

  defp match_visibility?(_t, "all"), do: true

  defp match_visibility?(t, "public"), do: (t.visibility || "public") != "private"
  defp match_visibility?(t, "private"), do: t.visibility == "private"

  defp match_assignee?(_t, "all"), do: true
  defp match_assignee?(t, "unassigned"), do: is_nil(t.assigned_to) or t.assigned_to == ""
  defp match_assignee?(t, val), do: t.assigned_to == val

  defp match_capability?(_t, "all"), do: true
  defp match_capability?(t, val), do: t.capability == val

  defp match_tag?(_t, "all"), do: true
  defp match_tag?(t, val), do: val in Task.parse_tag_list(t.tags || "")

  defp match_query?(_t, ""), do: true

  defp match_query?(t, q) do
    String.contains?(String.downcase(t.title || ""), q) or
      String.contains?(String.downcase(t.description || ""), q) or
      String.contains?(String.downcase(t.capability || ""), q) or
      String.contains?(String.downcase(t.team || ""), q) or
      String.contains?(String.downcase(t.assigned_to || ""), q) or
      String.contains?(String.downcase(t.tags || ""), q)
  end

  defp group_by_column(tasks) do
    %{
      "open" => Enum.filter(tasks, &(&1.status in ["open", "ready", "assigned"])),
      "in_progress" => Enum.filter(tasks, &(&1.status == "in_progress")),
      "review" => Enum.filter(tasks, &(&1.status == "review")),
      "completed" => Enum.filter(tasks, &(&1.status == "completed")),
      "blocked" => Enum.filter(tasks, &(&1.status in ["blocked", "failed"]))
    }
  end

  defp task_stats(tasks) do
    %{
      total: length(tasks),
      open: Enum.count(tasks, &(&1.status in ["open", "ready", "assigned"])),
      in_progress: Enum.count(tasks, &(&1.status == "in_progress")),
      review: Enum.count(tasks, &(&1.status == "review")),
      completed: Enum.count(tasks, &(&1.status == "completed")),
      blocked: Enum.count(tasks, &(&1.status in ["blocked", "failed"])),
      public: Enum.count(tasks, &(&1.visibility != "private")),
      private: Enum.count(tasks, &(&1.visibility == "private"))
    }
  end

  # Güvenli erişim (fonksiyon yoksa boş dön)
  defp safe_list_distinct_teams do
    Task.list_distinct_teams()
  rescue
    _ -> []
  end

  defp safe_workload_counts do
    Task.workload_counts()
  rescue
    _ -> []
  end

  defp safe_list_archived do
    Task.list_archived()
  rescue
    _ -> []
  end

  defp safe_length(nil), do: 0
  defp safe_length(%Ecto.Association.NotLoaded{}), do: 0
  defp safe_length(list) when is_list(list), do: length(list)
  defp safe_length(_), do: 0

  defp sender_badge(msg) do
    if msg.sender_id == "human", do: "bg-indigo-600 text-white", else: "bg-emerald-600 text-white"
  end

  # ---- Public Helpers ----
  def priority_badge(priority) do
    case priority do
      p when p >= 2 -> {"P0 Acil", "bg-red-900/60 text-red-300 border-red-700"}
      1 -> {"P1 Yüksek", "bg-amber-900/60 text-amber-300 border-amber-700"}
      _ -> {"P2 Normal", "bg-neutral-800 text-neutral-400 border-neutral-700"}
    end
  end

  def team_label(team) do
    case team do
      "core" -> "⚡ Çekirdek"
      "agents" -> "🤖 Ajanlar"
      "security" -> "🛡️ Güvenlik"
      "infra" -> "🏗️ Altyapı"
      "design" -> "🎨 Tasarım"
      "Core" -> "⚡ Çekirdek"
      "Agents" -> "🤖 Ajanlar"
      "Security" -> "🛡️ Güvenlik"
      "Infra" -> "🏗️ Altyapı"
      "Design" -> "🎨 Tasarım"
      _ -> "📁 #{team}"
    end
  end

  # Deadline chip için {label, class}
  def deadline_chip(nil), do: nil

  def deadline_chip(%DateTime{} = dt) do
    date = DateTime.to_date(dt)

    case Date.compare(date, Date.utc_today()) do
      :lt ->
        days = Date.diff(Date.utc_today(), date)
        {"⏰ Geçti #{days}g", "bg-red-950/60 text-red-300 border-red-800"}

      :eq ->
        {"⏰ Bugün", "bg-amber-950/60 text-amber-300 border-amber-700"}

      :gt ->
        days = Date.diff(date, Date.utc_today())

        label =
          cond do
            days == 1 -> "⏰ Yarın"
            days <= 7 -> "⏰ #{days}g"
            true -> "⏰ #{format_short_date(date)}"
          end

        {"#{label}", "bg-neutral-800 text-neutral-300 border-neutral-700"}
    end
  end

  def deadline_chip(_), do: nil

  # Detay modal'daki durum rozeti için sınıf
  def status_badge_class(status) do
    case to_string(status || "") do
      "open" -> "bg-sky-950/40 text-sky-300 border border-sky-800"
      "in_progress" -> "bg-amber-950/40 text-amber-300 border border-amber-800"
      "review" -> "bg-purple-950/40 text-purple-300 border border-purple-800"
      "completed" -> "bg-emerald-950/40 text-emerald-300 border border-emerald-800"
      "blocked" -> "bg-rose-950/40 text-rose-300 border border-rose-800"
      _ -> "bg-neutral-800 text-neutral-300 border border-neutral-700"
    end
  end

  # Aktivite ikonu (event_icon/1)
  def event_icon(action) do
    case to_string(action || "") do
      "created" -> "✨"
      "status_changed" -> "🔄"
      "assigned" -> "👤"
      "commented" -> "💬"
      "edited" -> "✏️"
      "archived" -> "🗄️"
      "unarchived" -> "↩️"
      "deleted" -> "🗑️"
      "subtask_added" -> "🧩"
      _ -> "📌"
    end
  end

  # Aksiyon etiketleri (Türkçe)
  def event_action_label(action) do
    case to_string(action || "") do
      "created" -> "Kart oluşturuldu"
      "status_changed" -> "Durum değiştirildi"
      "assigned" -> "Atama yapıldı"
      "commented" -> "Yorum eklendi"
      "edited" -> "Kart düzenlendi"
      "archived" -> "Arşive taşındı"
      "unarchived" -> "Arşivden geri alındı"
      "deleted" -> "Kart silindi"
      "subtask_added" -> "Alt görev eklendi"
      _ -> "Etkinlik"
    end
  end

  # Göreceli zaman (az önce, Xd önce, ...)
  def format_rel(nil), do: ""

  def format_rel(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "az önce"
      diff < 3600 -> "#{div(diff, 60)}dk önce"
      diff < 86_400 -> "#{div(diff, 3600)}sa önce"
      diff < 604_800 -> "#{div(diff, 86_400)}g önce"
      true -> format_short_date(DateTime.to_date(dt))
    end
  end

  def format_rel(_), do: ""

  def format_short_date(%Date{} = d) do
    "#{String.pad_leading(to_string(d.day), 2, "0")}.#{String.pad_leading(to_string(d.month), 2, "0")}"
  end

  def format_short_date(_), do: ""

  # Tam tarih formatı (dd.mm HH:MM) — eski format_date ile uyumlu
  def format_date(nil), do: "—"

  def format_date(%DateTime{} = dt) do
    d = DateTime.to_date(dt)
    t = DateTime.to_time(dt)

    day = String.pad_leading(to_string(d.day), 2, "0")
    month = String.pad_leading(to_string(d.month), 2, "0")
    hh = String.pad_leading(to_string(t.hour), 2, "0")
    mm = String.pad_leading(to_string(t.minute), 2, "0")

    "#{day}.#{month} #{hh}:#{mm}"
  end

  def format_date(_), do: "—"

  # <input type="date"> için ISO tarih (yyyy-mm-dd)
  def format_date_input(nil), do: ""

  def format_date_input(%DateTime{} = dt) do
    d = DateTime.to_date(dt)

    "#{d.year}-#{String.pad_leading(to_string(d.month), 2, "0")}-#{String.pad_leading(to_string(d.day), 2, "0")}"
  end

  def format_date_input(_), do: ""

  # ---- Private Parsers ----
  defp parse_int(val, default) do
    case Integer.parse(to_string(val || "")) do
      {num, _} -> num
      :error -> default
    end
  end

  defp parse_date(str) when is_binary(str) do
    case String.trim(str) do
      "" -> :error
      s -> Date.from_iso8601(s)
    end
  end

  defp parse_date(_), do: :error

  # deadline string -> %DateTime{} | nil
  defp build_deadline_at(nil), do: nil
  defp build_deadline_at(""), do: nil

  defp build_deadline_at(str) when is_binary(str) do
    case parse_date(str) do
      {:ok, %Date{} = date} ->
        case DateTime.new(date, ~T[23:59:59]) do
          {:ok, dt} -> DateTime.truncate(dt, :second)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp build_deadline_at(_), do: nil

  # Takım adını düzenle: boşsa "Core", trim uygula
  defp normalize_team(nil), do: "Core"

  defp normalize_team(val) when is_binary(val) do
    case String.trim(val) do
      "" -> "Core"
      s -> s
    end
  end

  defp normalize_team(_), do: "Core"

  # Filtre barındaki takım <select> için {label, value} listesi
  def team_filter_options(all_teams) when is_list(all_teams) do
    Enum.map(all_teams, fn team -> {team_label(team), team} end)
  end

  def team_filter_options(_), do: Enum.map(@teams, fn {name, id} -> {name, id} end)

  # Bir kartın alt görev sayısını döndürür (Task.loaded_children üzerinden ya da sorgu ile)
  def child_count(_task), do: 0
end
