defmodule AgentbotWeb.DeploymentsLive do
  @moduledoc """
  Deployments — agent'ların kendi hesaplarında açtığı servisler.

  AB yönetmez, doğrular: provisioning → verifying → live/failed.
  QM "check --live" felsefesi.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Provisioning
  alias AgentbotCore.Modules.Provisioning.DeploymentVerifier

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5_000, :tick)
    end

    {:ok, assign_deployments(socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign_deployments(socket)}
  end

  @impl true
  def handle_event("verify", %{"id" => id}, socket) do
    DeploymentVerifier.verify_deployment(String.to_integer(id))
    {:noreply, put_flash(socket, :info, "Doğrulama başlatıldı — health check koşuyor")}
  end

  defp assign_deployments(socket) do
    assign(socket, deployments: Provisioning.list_deployments())
  end

  defp status_badge("live"), do: "ab-badge--ok"
  defp status_badge("failed"), do: "ab-badge--err"
  defp status_badge("verifying"), do: "ab-badge--warn"
  defp status_badge(_), do: "ab-badge--ghost"
end
