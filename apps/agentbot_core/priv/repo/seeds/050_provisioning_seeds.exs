defmodule AgentbotCore.Repo.Seeds.ProvisioningSeeds do
  @moduledoc """
  Provisioning broker seed data — fly.io provider ve pong recipe.

  Mock E2E testi için temel data.
  """

  alias AgentbotCore.Repo
  alias AgentbotCore.Modules.Provisioning

  @doc """
  Seed data'yı çalıştır
  """
  def run do
    create_fly_provider()
    create_pong_recipe()
  end

  defp create_fly_provider do
    case Provisioning.get_provider_by_slug("fly") do
      nil ->
        {:ok, _provider} =
          Provisioning.create_provider(%{
            name: "Fly.io",
            slug: "fly",
            referral_url_template: "https://fly.io/ref/{{CODE}}",
            referral_code: nil,
            prerequisites: %{"required" => ["flyctl", "fly account"]},
            status: "active",
            metadata: %{"icon" => "🪁", "docs_url" => "https://fly.io/docs/"}
          })

        IO.puts("✅ Fly.io provider oluşturuldu")

      _provider ->
        IO.puts("ℹ️ Fly.io provider zaten mevcut")
    end
  end

  defp create_pong_recipe do
    case Provisioning.get_recipe_by_name("pong-service") do
      nil ->
        fly_provider = Provisioning.get_provider_by_slug("fly")

        if fly_provider do
          manifest = %{
            "contract" => 1,
            "capability" => "pong",
            "provider" => "fly.io",
            "prerequisites" => ["flyctl", "fly account"],
            "estimated_cost" => "~$3/ay",
            "referral_required" => true,
            "verify" => %{"health_path" => "/health", "timeout_s" => 300}
          }

          skill = """
          # Pong Service Deployment Recipe

          Bu recipe minimal bir HTTP servis deploy eder.

          ## Önceki şartlar

          - `flyctl` kurulu olmalı
          - Fly.io hesabınız olmalı (AB referral link'i ile kayıt olabilirsiniz)

          ## Adımlar

          1. Bu servisi deploy edin:
             ```bash
             # AB'den aldığınız referral link'i kullanarak hesap açın
             # Sonra deploy komutunu çalıştırın
             ```

          2. Health endpoint'i `/health` adresinde çalışmalıdır

          3. Endpoint URL'sini AB'ye register edin

          ## Verify checklist

          - [ ] Servis `/health` endpoint'ine 200 dönmeli
          - [ ] Endpoint URL'si dışarıdan erişilebilir olmalı
          - [ ] Attribution code kayıtlı olmalı
          """

          {:ok, _recipe} =
            Provisioning.create_recipe(%{
              name: "pong-service",
              capability_name: "pong",
              provider_id: fly_provider.id,
              contract_version: 1,
              manifest: manifest,
              skill: skill,
              verify_checklist: %{
                "health_endpoint" => true,
                "external_access" => true,
                "attribution" => true
              },
              estimated_cost: "~$3/ay",
              status: "active",
              metadata: %{"description" => "Minimal HTTP health check servisi"}
            })

          IO.puts("✅ Pong recipe oluşturuldu")
        else
          IO.puts("❌ Fly.io provider bulunamadı, pong recipe oluşturulamadı")
        end

      _recipe ->
        IO.puts("ℹ️ Pong recipe zaten mevcut")
    end
  end
end
