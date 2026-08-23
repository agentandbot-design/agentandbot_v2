defmodule AgentbotWeb.RecipesLive do
  @moduledoc """
  Recipe kataloğu — capability açmak için standart reçeteler.

  QM deployment directory'den ilhamla: manifest + skill + verify
  checklist, content-hash ile versiyonlanmış.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Provisioning

  @impl true
  def mount(params, _session, socket) do
    capability = Map.get(params, "capability")
    {:ok, assign(socket, recipes: list_recipes(capability), filter: capability)}
  end

  defp list_recipes(nil), do: Provisioning.list_recipes()
  defp list_recipes(capability), do: Provisioning.list_recipes_by_capability(capability)
end
