defmodule AgentbotWeb.ActivityLogLive do
  @moduledoc """
  SAP Danışmanlık Günlüğü — Kanban görünümü.
  Günlük aktiviteleri "draft", "in_progress", "done" kolonlarında listeler.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.ActivityLog

  @impl true
  def mount(_params, _session, socket) do
    date = Date.utc_today()
    activities = ActivityLog.list_by_date(date)

    {:ok,
     socket
     |> assign(:date, date)
     |> assign(:activities, activities)
     |> assign(:statuses, ActivityLog.statuses())
     |> assign(:categories, ActivityLog.categories())
     |> assign(:editing_activity, nil)
     |> assign(:show_form, false)
     |> assign(:new_activity, %{
       "date" => Date.to_string(date),
       "title" => "",
       "content" => "",
       "tags" => "",
       "status" => "draft",
       "category" => "sap"
     })}
  end

  @impl true
  def handle_params(%{"date" => date_str}, _uri, socket) do
    date = case Date.from_iso8601(date_str) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
    activities = ActivityLog.list_by_date(date)
    {:noreply, assign(socket, date: date, activities: activities)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("save_activity", %{"activity_log" => params}, socket) do
    params = Map.put_new(params, "created_by", "ilkerkaan")

    case ActivityLog.create(params) do
      {:ok, _activity} ->
        activities = ActivityLog.list_by_date(socket.assigns.date)
        {:noreply,
         socket
         |> assign(:activities, activities)
         |> assign(:show_form, false)
         |> assign(:new_activity, %{
           "date" => Date.to_string(socket.assigns.date),
           "title" => "",
           "content" => "",
           "tags" => "",
           "status" => "draft",
           "category" => "sap"
         })
         |> put_flash(:info, "Aktivite eklendi.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    case ActivityLog.update_status(id, status) do
      {:ok, _} ->
        activities = ActivityLog.list_by_date(socket.assigns.date)
        {:noreply, assign(socket, activities: activities)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Statü güncellenemedi.")}
    end
  end

  def handle_event("delete_activity", %{"id" => id}, socket) do
    activity = ActivityLog.get!(id)
    case ActivityLog.delete(activity) do
      {:ok, _} ->
        activities = ActivityLog.list_by_date(socket.assigns.date)
        {:noreply, assign(socket, activities: activities)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Silinemedi.")}
    end
  end

  def handle_event("sync_google", %{"id" => id}, socket) do
    activity = ActivityLog.get!(id)
    case ActivityLog.sync_to_google(activity) do
      {:ok, updated} ->
        activities = ActivityLog.list_by_date(socket.assigns.date)
        {:noreply,
         socket
         |> assign(:activities, activities)
         |> put_flash(:info, "Google Docs'a sync edildi: #{updated.google_doc_url}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Sync başarısız: #{inspect(reason)}")}
    end
  end

  def handle_event("change_date", %{"date" => date_str}, socket) do
    date = case Date.from_iso8601(date_str) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
    activities = ActivityLog.list_by_date(date)
    {:noreply, assign(socket, date: date, activities: activities)}
  end

  defp activities_by_status(activities, status) do
    Enum.filter(activities, &(&1.status == status))
  end

  defp status_color("draft"), do: "bg-neutral-600"
  defp status_color("in_progress"), do: "bg-amber-600"
  defp status_color("done"), do: "bg-emerald-600"
  defp status_color("archived"), do: "bg-neutral-800"
  defp status_color(_), do: "bg-neutral-600"

  defp category_icon("sap"), do: "📊"
  defp category_icon("infra"), do: "🔧"
  defp category_icon("meeting"), do: "👥"
  defp category_icon("note"), do: "📝"
  defp category_icon("idea"), do: "💡"
  defp category_icon(_), do: "📋"
end
