defmodule AgentbotCore.Modules.Provisioning do
  @moduledoc """
  Provisioning Broker — agent'ların kendi hesaplarında capability açması için
  recipe, deployment ve attribution yönetimi.

  QM deployment directory felsefesinden: AB deploy etmez, sadece recipe verir,
  doğrular ve attribüte eder. Affiliate gelir modeli için attribution tracking.
  """

  import Ecto.Query
  alias AgentbotCore.Modules.Provisioning.Deployment
  alias AgentbotCore.Modules.Provisioning.Provider
  alias AgentbotCore.Modules.Provisioning.Recipe
  alias AgentbotCore.Modules.Provisioning.ReferralEvent
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Repo

  @doc """
  Aktif provider listesi
  """
  def list_providers do
    Repo.all(from(p in Provider, where: p.status == "active"))
  end

  @doc """
  Tüm aktif recipe'ler (provider ile)
  """
  def list_recipes do
    Repo.all(from(r in Recipe, where: r.status == "active", preload: [:provider]))
  end

  @doc """
  Tüm deployment'lar (provider + recipe + agent ile, en yeni önce)
  """
  def list_deployments do
    Repo.all(
      from(d in Deployment, order_by: [desc: d.inserted_at], preload: [:provider, :recipe])
    )
  end

  @doc """
  Provider slug'ına göre getir
  """
  def get_provider_by_slug(slug) do
    Repo.get_by(Provider, slug: slug, status: "active")
  end

  @doc """
  Provider oluştur
  """
  def create_provider(attrs) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Belirli capability'i sağlayacak recipe'ler
  """
  def list_recipes_by_capability(capability_name) do
    Repo.all(
      from(r in Recipe,
        where: r.capability_name == ^capability_name and r.status == "active",
        preload: [:provider]
      )
    )
  end

  @doc """
  Recipe'yi ID'ye göre getir (provider ile birlikte)
  """
  def get_recipe(id) do
    Repo.preload(Repo.get(Recipe, id), :provider)
  end

  @doc """
  Recipe'yi adına göre getir
  """
  def get_recipe_by_name(name) do
    case Repo.get_by(Recipe, name: name) do
      nil -> nil
      recipe -> Repo.preload(recipe, :provider)
    end
  end

  @doc """
  Recipe oluştur — content_hash otomatik hesaplanır
  """
  def create_recipe(attrs) do
    content = build_content_hash(attrs)
    attrs_with_hash = Map.put(attrs, :content_hash, content)

    %Recipe{}
    |> Recipe.changeset(attrs_with_hash)
    |> Repo.insert()
  end

  @doc """
  Deployment oluştur — attribution code otomatik üretilir
  """
  def create_deployment(attrs) do
    attribution_code = generate_attribution_code()

    # Timestamp'leri manuel second-precision olarak ayarla (DB schema: timestamp(0))
    now = DateTime.truncate(DateTime.utc_now(), :second)

    attrs_with_code =
      Map.merge(attrs, %{
        attribution_code: attribution_code,
        inserted_at: now,
        updated_at: now
      })

    %Deployment{}
    |> Deployment.changeset(attrs_with_code)
    |> Repo.insert()
    |> case do
      {:ok, deployment} ->
        create_referral_event(deployment, "deploy_initiated", nil)
        {:ok, deployment}

      error ->
        error
    end
  end

  @doc """
  Deployment durumunu güncelle
  """
  def update_deployment_status(id, status, opts \\ []) do
    Repo.get(Deployment, id)
    |> Deployment.changeset(
      Map.merge(
        %{status: status},
        case status do
          "live" -> %{verified_at: DateTime.truncate(DateTime.utc_now(), :second)}
          "failed" -> %{failed_reason: Keyword.get(opts, :reason)}
          _ -> %{}
        end
      )
    )
    |> Repo.update()
  end

  @doc """
  Deployment URL'sine health check yap
  """
  def check_deployment_health(deployment_id) do
    deployment = Repo.get(Deployment, deployment_id)

    if deployment && deployment.endpoint_url && deployment.health_path do
      url = "#{deployment.endpoint_url}#{deployment.health_path}"

      case Req.get(url, connect_timeout: 5000, receive_timeout: 5000) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          {:ok, :healthy}

        {:ok, response} ->
          {:error, "HTTP #{response.status}"}

        {:error, error} ->
          {:error, error.reason}
      end
    else
      {:error, :deployment_not_found_or_missing_url}
    end
  end

  @doc """
  Referral link oluştur — provider template'i ve attribution code'u kullanır
  """
  def build_referral_link(%Provider{} = provider, attribution_code) do
    template = provider.referral_url_template
    String.replace(template, "{{CODE}}", attribution_code)
  end

  @doc """
  Capability gap'i dolduracak recipe önerisi
  """
  def suggest_recipe_for_gap(gap_id) do
    gap = Repo.get(CapabilityGap, gap_id)

    if gap do
      recipes = list_recipes_by_capability(gap.capability_name)

      if Enum.any?(recipes) do
        suggested = Enum.at(recipes, 0)

        gap
        |> Ecto.Changeset.change(suggested_recipe_id: suggested.id)
        |> Repo.update()

        {:ok, suggested}
      else
        {:error, :no_recipe_found}
      end
    else
      {:error, :gap_not_found}
    end
  end

  @doc """
  Deployment vererek capability sağlanır (agent recipe'den deploy etti)
  """
  def register_capability_from_deployment(deployment_id) do
    deployment = Repo.preload(Repo.get(Deployment, deployment_id), [:recipe, :agent_credential])

    if deployment do
      capability_name = deployment.recipe.capability_name

      # Capability oluştur veya getir
      capability =
        Repo.get_by(Capability, name: capability_name) ||
          Repo.insert!(%Capability{
            name: capability_name,
            category: "provisioned",
            description: "Provisioning: #{deployment.recipe.name}",
            status: "active"
          })

      # İlgili gap'i otomatik olarak fulfilled olarak işaretle
      case Repo.get_by(CapabilityGap, capability_name: capability_name) do
        nil -> :ok
        _gap -> CapabilityGap.fulfill(capability_name, deployment.agent_credential.agent_id)
      end

      {:ok, capability}
    else
      {:error, :deployment_not_found}
    end
  end

  defp build_content_hash(%{skill: skill, manifest: manifest}) do
    content = Jason.encode!(%{skill: skill, manifest: manifest})
    Base.encode16(:crypto.hash(:sha256, content), case: :lower)
  end

  defp build_content_hash(_), do: nil

  defp generate_attribution_code do
    Base.encode64(:crypto.strong_rand_bytes(8), padding: false)
  end

  @doc """
  Geçici attribution code üret — recipe preview için (deployment olmadan)
  """
  def generate_temp_attribution_code do
    generate_attribution_code()
  end

  defp create_referral_event(%Deployment{} = deployment, event_type, referral_link) do
    %ReferralEvent{
      provider_id: deployment.provider_id,
      deployment_id: deployment.id,
      event_type: event_type,
      attribution_code: deployment.attribution_code,
      referral_link: referral_link,
      occurred_at: DateTime.truncate(DateTime.utc_now(), :second)
    }
    |> ReferralEvent.changeset(%{})
    |> Repo.insert()
  end
end
