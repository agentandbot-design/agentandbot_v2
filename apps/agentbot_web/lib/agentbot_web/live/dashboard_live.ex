defmodule AgentbotWeb.DashboardLive do
  @moduledoc """
  Ana sayfa — ne yapar, nasıl kullanılır, canlı durum.

  Bauhaus: her eleman fonksiyonel. Süs yok.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Registry.{Capability, CapabilityGap}
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Repo
  alias AgentbotCore.Modules.Security.AgentCredential

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AgentbotCore.PubSub.subscribe("presence")
      :timer.send_interval(10_000, :tick)
    end

    {:ok,
     socket
     |> assign_stats()
     |> assign(:top_gaps, CapabilityGap.list_top_gaps(5))
     |> assign(:recent_tasks, recent_tasks())
     |> assign(:active_capabilities, list_capabilities())}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, refresh(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp refresh(socket) do
    socket
    |> assign_stats()
    |> assign(:top_gaps, CapabilityGap.list_top_gaps(5))
    |> assign(:recent_tasks, recent_tasks())
    |> assign(:active_capabilities, list_capabilities())
  end

  defp assign_stats(socket) do
    socket
    |> assign(:executor_count, count_executors())
    |> assign(:capability_count, Repo.aggregate(Capability, :count))
    |> assign(:task_count, Repo.aggregate(Task, :count))
    |> assign(:completed_tasks, count_by_status("completed"))
    |> assign(:gap_count, count_open_gaps())
  end

  defp count_executors do
    AgentCredential |> where([c], c.is_active == true) |> Repo.aggregate(:count)
  end

  defp count_by_status(status) do
    Task |> where([t], t.status == ^status) |> Repo.aggregate(:count)
  end

  defp count_open_gaps do
    CapabilityGap |> where([g], g.fulfilled == false) |> Repo.aggregate(:count)
  end

  defp recent_tasks do
    Task |> order_by([t], desc: t.inserted_at) |> limit(5) |> Repo.all()
  end

  defp list_capabilities do
    Capability.list_active()
  end

  defp status_badge("completed"), do: "badge-success"
  defp status_badge("failed"), do: "badge-error"
  defp status_badge("assigned"), do: "badge-info"
  defp status_badge("in_progress"), do: "badge-warning"
  defp status_badge(_), do: "badge-ghost"
end
