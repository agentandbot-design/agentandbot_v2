defmodule AgentbotWeb.DashboardLive do
  @moduledoc """
  Ana sayfa — ne yapar, nasıl kullanılır, canlı durum.

  Bauhaus: her eleman fonksiyonel. Süs yok.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Marketplace.Artifact
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Provisioning.Deployment
  alias AgentbotCore.Modules.Provisioning.ReferralEvent
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Modules.Registry.ExecutorResource
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

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
     |> assign(:capabilities, list_capabilities_with_providers())
     |> assign(:logo_proposals, Artifact.list_by_task(13))
     |> assign(:resource_summary, ExecutorResource.summary())}
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
    |> assign(:capabilities, list_capabilities_with_providers())
    |> assign(:logo_proposals, Artifact.list_by_task(13))
    |> assign(:resource_summary, ExecutorResource.summary())
  end

  defp assign_stats(socket) do
    socket
    |> assign(:executor_count, count_executors())
    |> assign(:capability_count, Repo.aggregate(Capability, :count))
    |> assign(:task_count, Repo.aggregate(Task, :count))
    |> assign(:completed_tasks, count_by_status("completed"))
    |> assign(:gap_count, count_open_gaps())
    |> assign(:deployment_count, count_deployments())
    |> assign(:referral_count, count_referral_events())
  end

  defp count_executors do
    Repo.aggregate(where(AgentCredential, [c], c.is_active == true), :count)
  end

  defp count_by_status(status) do
    Repo.aggregate(where(Task, [t], t.status == ^status), :count)
  end

  defp count_open_gaps do
    Repo.aggregate(where(CapabilityGap, [g], g.fulfilled == false), :count)
  end

  defp count_deployments do
    Repo.aggregate(Deployment, :count)
  end

  defp count_referral_events do
    Repo.aggregate(ReferralEvent, :count)
  end

  defp recent_tasks do
    Task |> order_by([t], desc: t.inserted_at) |> limit(5) |> Repo.all()
  end

  defp list_capabilities_with_providers do
    Enum.map(Capability.list_active(), fn cap ->
      providers = Capability.providers(cap.name)

      %{
        name: cap.name,
        category: cap.category,
        description: cap.description,
        providers: providers
      }
    end)
  end

  defp status_badge("completed"), do: "badge-success"
  defp status_badge("failed"), do: "badge-error"
  defp status_badge("assigned"), do: "badge-info"
  defp status_badge("in_progress"), do: "badge-warning"
  defp status_badge(_), do: "badge-ghost"

  defp executor_badge("agent"), do: "badge-primary"
  defp executor_badge("tool"), do: "badge-secondary"
  defp executor_badge("mcp"), do: "badge-accent"
  defp executor_badge("workflow"), do: "badge-info"
  defp executor_badge("script"), do: "badge-warning"
  defp executor_badge("api"), do: "badge-success"
  defp executor_badge(_), do: "badge-ghost"
end
