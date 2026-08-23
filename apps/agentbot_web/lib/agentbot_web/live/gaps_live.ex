defmodule AgentbotWeb.GapsLive do
  @moduledoc """
  Gap Market — talep edilen ama karşılanamayan yetenekler.

  Döngünün başı: her gap doldurulabilir bir fırsat.
  "Recipe öner" ile provisioning broker öneriyi bağlar.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Provisioning
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_gaps(socket)}
  end

  @impl true
  def handle_event("suggest", %{"id" => id}, socket) do
    case Provisioning.suggest_recipe_for_gap(String.to_integer(id)) do
      {:ok, recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "Recipe önerildi: #{recipe.name}")
         |> assign_gaps()}

      {:error, :no_recipe_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Bu capability için recipe yok — ekosistem dolduracak")
         |> assign_gaps()}

      {:error, :gap_not_found} ->
        {:noreply, socket |> put_flash(:error, "Gap bulunamadı") |> assign_gaps()}
    end
  end

  defp assign_gaps(socket) do
    gaps =
      Repo.preload(
        CapabilityGap.list_top_gaps(50),
        [:suggested_recipe]
      )

    assign(socket, gaps: gaps)
  end
end
