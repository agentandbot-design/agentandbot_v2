defmodule AgentbotWeb.ResourceController do
  @moduledoc """
  Resource Marketplace API.

  "Gel CPU ver para kazan. Gel API bağla para kazan."

  Executor'lar kaynak sağlar: CPU, RAM, GPU, Storage, API, Bandwidth
  Task'lar gereksinim bildirir.
  """

  use AgentbotWeb, :controller

  import Ecto.Query

  alias AgentbotCore.Modules.Registry.ExecutorResource
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

  @doc "Tüm sistem kaynak özeti"
  def index(conn, _params) do
    summary = ExecutorResource.summary()
    types = ExecutorResource.resource_types()

    json(conn, %{
      description: "Mevcut kaynak havuzu. Executor'lar ne sağlıyor.",
      resource_types: types,
      summary: summary,
      message: "Gel CPU ver para kazan. Gel API bağla para kazan."
    })
  end

  @doc "Belirli kaynak tipine göre sağlayıcıları bul"
  def by_type(conn, %{"type" => resource_type}) do
    min_amount = String.to_integer(conn.query_params["min"] || "0")
    providers = ExecutorResource.find_providers(resource_type, min_amount)

    json(conn, %{
      resource_type: resource_type,
      providers: providers,
      count: length(providers)
    })
  end

  @doc "Executor kaynak sağlar (CPU, RAM, GPU, API)"
  def provide(conn, params) do
    agent_id = conn.assigns.agent_id

    credential =
      AgentCredential
      |> where([c], c.agent_id == ^agent_id and c.is_active == true)
      |> order_by([c], desc: c.inserted_at)
      |> limit(1)
      |> Repo.one()

    if is_nil(credential) do
      conn |> put_status(404) |> json(%{error: "Executor bulunamadı"})
    else
      resource_type = params["resource_type"]
      amount = params["amount"]
      unit = params["unit"] || default_unit(resource_type)
      cost = params["cost_per_unit"]

      case ExecutorResource.add(credential.id, resource_type, amount, unit, cost) do
        {:ok, resource} ->
          conn
          |> put_status(201)
          |> json(%{
            status: "provided",
            resource_type: resource.resource_type,
            amount: resource.amount,
            unit: resource.unit,
            message: "#{resource_type} kaynağı sağlandı"
          })

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          conn |> put_status(422) |> json(%{errors: errors})
      end
    end
  end

  defp default_unit("cpu"), do: "cores"
  defp default_unit("ram"), do: "MB"
  defp default_unit("gpu"), do: "cores"
  defp default_unit("storage"), do: "GB"
  defp default_unit("api"), do: "calls/day"
  defp default_unit("bandwidth"), do: "mbps"
  defp default_unit(_), do: "units"
end
