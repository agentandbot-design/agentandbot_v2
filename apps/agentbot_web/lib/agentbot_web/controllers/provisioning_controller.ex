defmodule AgentbotWeb.ProvisioningController do
  @moduledoc """
  Provisioning API endpoint'leri — gap→recipe→deploy→verify döngüsü.

  Agent'lar capability açmak için recipe alır, deployment'ı register eder,
  AB live-verify eder ve attribution kaydeder.
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Provisioning
  alias AgentbotCore.Modules.Provisioning.Deployment
  alias AgentbotCore.Modules.Provisioning.DeploymentVerifier
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Repo

  @doc """
  Gap'i dolduracak recipe'leri listele
  """
  def index_gap_recipes(conn, %{"id" => gap_id}) do
    gap = Repo.get(CapabilityGap, gap_id)

    if gap do
      recipes = Provisioning.list_recipes_by_capability(gap.capability_name)

      json(conn, %{
        gap_id: gap.id,
        capability_name: gap.capability_name,
        recipes: Enum.map(recipes, &recipe_json/1)
      })
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Gap not found"})
    end
  end

  @doc """
  Recipe detayı + referral link + attribution code
  """
  def show_recipe(conn, %{"id" => recipe_id}) do
    case Provisioning.get_recipe(recipe_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Recipe not found"})

      recipe ->
        attribution_code = Provisioning.generate_temp_attribution_code()
        referral_link = Provisioning.build_referral_link(recipe.provider, attribution_code)

        json(conn, %{
          id: recipe.id,
          name: recipe.name,
          capability_name: recipe.capability_name,
          provider: %{
            id: recipe.provider.id,
            name: recipe.provider.name,
            slug: recipe.provider.slug
          },
          manifest: recipe.manifest,
          skill: recipe.skill,
          verify_checklist: recipe.verify_checklist,
          estimated_cost: recipe.estimated_cost,
          content_hash: recipe.content_hash,
          referral_link: referral_link,
          attribution_code: attribution_code,
          referral_required: recipe.manifest["referral_required"] || false
        })
    end
  end

  @doc """
  Deployment register (authenticated) — agent kendi hesabında açtı
  """
  def create_deployment(conn, params) do
    agent_id = get_agent_id(conn)

    case Provisioning.create_deployment(
           Map.merge(params, %{
             agent_credential_id: agent_id.id
           })
         ) do
      {:ok, deployment} ->
        json(conn, %{
          id: deployment.id,
          status: deployment.status,
          attribution_code: deployment.attribution_code,
          message: "Deployment registered, verification starting..."
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to register deployment", details: errors_on(changeset)})
    end
  end

  @doc """
  Deployment detayı
  """
  def show_deployment(conn, %{"id" => id}) do
    deployment = Repo.preload(Repo.get(Deployment, id), [:provider, :recipe])

    if deployment do
      json(conn, deployment_json(deployment))
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Deployment not found"})
    end
  end

  @doc """
  Deployment'i tekrar verify et (manual trigger)
  """
  def verify_deployment(conn, %{"id" => id}) do
    case DeploymentVerifier.verify_deployment(id) do
      {:ok, :scheduled} ->
        json(conn, %{message: "Verification started"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  defp recipe_json(recipe) do
    %{
      id: recipe.id,
      name: recipe.name,
      capability_name: recipe.capability_name,
      provider: %{
        id: recipe.provider.id,
        name: recipe.provider.name,
        slug: recipe.provider.slug
      },
      estimated_cost: recipe.estimated_cost,
      status: recipe.status
    }
  end

  defp deployment_json(deployment) do
    %{
      id: deployment.id,
      status: deployment.status,
      endpoint_url: deployment.endpoint_url,
      health_path: deployment.health_path,
      region: deployment.region,
      attribution_code: deployment.attribution_code,
      verified_at: deployment.verified_at,
      last_health_at: deployment.last_health_at,
      failed_reason: deployment.failed_reason,
      provider: %{
        id: deployment.provider.id,
        name: deployment.provider.name,
        slug: deployment.provider.slug
      },
      recipe: %{
        id: deployment.recipe.id,
        name: deployment.recipe.name,
        capability_name: deployment.recipe.capability_name
      },
      created_at: deployment.inserted_at,
      updated_at: deployment.updated_at
    }
  end

  defp get_agent_id(conn) do
    conn.assigns[:agent_credential]
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_atom(key), key) |> to_string()
      end)
    end)
  end
end
