defmodule AgentbotWeb.KanbanLive do
  @moduledoc """
  KanbanLive — AgentAndBot Özel Kanban Görev ve Problem Takip Panosu.

  Görevlerin, bulunan açıkların ve geliştirme hedeflerinin canlı takibi:
  Backlog / Açık → Sürüyor (In Progress) → İnceleme (Review) → Tamamlandı (Completed) / Engelli (Blocked).

  PubSub kanban:tasks üzerinden gerçek zamanlı canlı senkronizasyon.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Marketplace.Artifact
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.PubSub

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

  @assignees [
    {"Hermes Agent (Yerel)", "hermes-local"},
    {"Sara (Güvenlik / Review)", "sara"},
    {"OpenCode (Geliştirici)", "opencode"},
    {"İlker (İnsan)", "ilkerkaan"},
    {"Atanmamış", ""}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe("kanban:tasks")
    end

    socket =
      socket
      |> assign(:page_title, "Kanban Board")
      |> assign(:columns, @columns)
      |> assign(:capabilities, @capabilities)
      |> assign(:assignees, @assignees)
      |> assign(:filter_assignee, "all")
      |> assign(:filter_capability, "all")
      |> assign(:search_query, "")
      |> assign(:show_modal, false)
      |> assign(:show_artifact_modal, nil)
      |> assign(:new_task, %{
        "title" => "",
        "description" => "",
        "capability" => "bugfix",
        "priority" => "1",
        "assigned_to" => "hermes-local"
      })
      |> assign(:new_artifact, %{
        "title" => "",
        "content" => "",
        "artifact_type" => "report"
      })
      |> assign_tasks()

    {:ok, socket}
  end

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:show_artifact_modal, nil)}
  end

  @impl true
  def handle_event("update_new_task", %{"task" => task_params}, socket) do
    {:noreply, assign(socket, :new_task, Map.merge(socket.assigns.new_task, task_params))}
  end

  @impl true
  def handle_event("save_task", %{"task" => params}, socket) do
    priority =
      case Integer.parse(params["priority"] || "1") do
        {p, _} -> p
        :error -> 1
      end

    assigned_to =
      case params["assigned_to"] do
        "" -> nil
        val -> val
      end

    status = if is_nil(assigned_to), do: "open", else: "assigned"

    attrs = %{
      title: String.trim(params["title"] || ""),
      description: String.trim(params["description"] || ""),
      capability: params["capability"] || "general",
      priority: priority,
      assigned_to: assigned_to,
      created_by: "ilkerkaan",
      status: status
    }

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
             "priority" => "1",
             "assigned_to" => "hermes-local"
           })
           |> assign_tasks()
           |> put_flash(:info, "Kart başarıyla eklendi.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Kart kaydedilemedi. Lütfen alanları kontrol edin.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Kart başlığı zorunludur.")}
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
  def handle_event("open_artifact_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :show_artifact_modal, String.to_integer(id))}
  end

  @impl true
  def handle_event("submit_artifact_and_complete", %{"artifact" => params, "task_id" => task_id_str}, socket) do
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
  def handle_event("filter_assignee", %{"assignee" => val}, socket) do
    {:noreply, socket |> assign(:filter_assignee, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("filter_capability", %{"capability" => val}, socket) do
    {:noreply, socket |> assign(:filter_capability, val) |> assign_tasks()}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> assign_tasks()}
  end

  @impl true
  def handle_info({:task_updated, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info({:task_created, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info({:task_deleted, _}, socket), do: {:noreply, assign_tasks(socket)}
  def handle_info(_other, socket), do: {:noreply, socket}

  defp assign_tasks(socket) do
    all_tasks = Task.list_for_kanban()

    # İstatistikler
    stats = %{
      total: length(all_tasks),
      open: Enum.count(all_tasks, &(&1.status in ["open", "ready", "assigned"])),
      in_progress: Enum.count(all_tasks, &(&1.status == "in_progress")),
      review: Enum.count(all_tasks, &(&1.status == "review")),
      completed: Enum.count(all_tasks, &(&1.status == "completed")),
      blocked: Enum.count(all_tasks, &(&1.status in ["blocked", "failed"])),
      with_artifacts: Enum.count(all_tasks, &(not Enum.empty?(&1.artifacts)))
    }

    # Filtreleme
    f_assignee = socket.assigns[:filter_assignee] || "all"
    f_cap = socket.assigns[:filter_capability] || "all"
    f_q = String.downcase(String.trim(socket.assigns[:search_query] || ""))

    filtered_tasks =
      all_tasks
      |> Enum.filter(fn t ->
        match_assignee =
          case f_assignee do
            "all" -> true
            "unassigned" -> is_nil(t.assigned_to) or t.assigned_to == ""
            val -> t.assigned_to == val
          end

        match_cap =
          case f_cap do
            "all" -> true
            val -> t.capability == val
          end

        match_q =
          if f_q == "" do
            true
          else
            String.contains?(String.downcase(t.title || ""), f_q) or
              String.contains?(String.downcase(t.description || ""), f_q) or
              String.contains?(String.downcase(t.capability || ""), f_q) or
              String.contains?(String.downcase(t.assigned_to || ""), f_q)
          end

        match_assignee and match_cap and match_q
      end)

    # Kolonlara ayır
    tasks_by_column = %{
      "open" => Enum.filter(filtered_tasks, &(&1.status in ["open", "ready", "assigned"])),
      "in_progress" => Enum.filter(filtered_tasks, &(&1.status == "in_progress")),
      "review" => Enum.filter(filtered_tasks, &(&1.status == "review")),
      "completed" => Enum.filter(filtered_tasks, &(&1.status == "completed")),
      "blocked" => Enum.filter(filtered_tasks, &(&1.status in ["blocked", "failed"]))
    }

    socket
    |> assign(:stats, stats)
    |> assign(:tasks_by_column, tasks_by_column)
  end

  def priority_badge(priority) do
    case priority do
      p when p >= 2 -> {"P0 Acil", "bg-red-900/60 text-red-300 border-red-700"}
      1 -> {"P1 Yüksek", "bg-amber-900/60 text-amber-300 border-amber-700"}
      _ -> {"P2 Normal", "bg-neutral-800 text-neutral-400 border-neutral-700"}
    end
  end

  def format_date(nil), do: "—"
  def format_date(dt) do
    Calendar.strftime(dt, "%d.%m %H:%M")
  end
end
