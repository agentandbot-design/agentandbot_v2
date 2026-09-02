#!/usr/bin/env elixir

# Faz A Mock E2E Test — Gap→Recipe→Deploy→Verify→Fulfilled döngüsü

IO.puts("🧪 Faz A Mock E2E Test Başlıyor...")

# 2. Elixir kodu ile E2E test döngüsü
IO.puts("\n🔄 E2E Test Döngüsü Başlıyor:\n")

# Test fonksiyonları
defmodule TestHelper do
  import Ecto.Query
  alias AgentbotCore.Repo
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Modules.Provisioning

  def create_pong_gap do
    IO.puts("1️⃣  'pong' capability'si için gap oluşturuluyor...")

    # Önce mevcut "pong" gap'ini temizle (eğer varsa)
    case Repo.get_by(CapabilityGap, capability_name: "pong") do
      nil ->
        :ok

      existing_gap ->
        # Önce tüm deployment'ları sil
        pong_recipe_ids =
          from(r in AgentbotCore.Modules.Provisioning.Recipe,
            where: r.capability_name == "pong",
            select: r.id
          )
          |> Repo.all()

        if pong_recipe_ids != [] do
          from(d in AgentbotCore.Modules.Provisioning.Deployment,
            where: d.recipe_id in ^pong_recipe_ids
          )
          |> Repo.delete_all()
        end

        # Sonra gap'i sil
        Repo.delete(existing_gap)
    end

    # Yeni gap oluştur
    {:ok, gap} =
      %CapabilityGap{}
      |> Ecto.Changeset.change(%{
        capability_name: "pong",
        requested_count: 1,
        fulfilled: false
      })
      |> Repo.insert()

    IO.puts("✅ Gap oluşturuldu: ##{gap.id}")
    gap
  end

  def get_suggested_recipe(gap_id) do
    IO.puts("\n2️⃣  Gap için recipe önerisi isteniyor...")

    case Provisioning.suggest_recipe_for_gap(gap_id) do
      {:ok, recipe} ->
        IO.puts("✅ Recipe önerildi: #{recipe.name} (#{recipe.capability_name})")
        recipe

      {:error, reason} ->
        IO.puts("❌ Recipe önerilemedi: #{reason}")
        nil
    end
  end

  def mock_deployment(gap, recipe, hermes_agent_id) do
    IO.puts("\n3️⃣  Mock deployment oluşturuluyor...")

    # Kısa test için sadece deployment record'ı manuel oluştur (timestamp sorunu aşmak için)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, deployment} =
      %AgentbotCore.Modules.Provisioning.Deployment{
        # Basit test için hardcoded
        agent_credential_id: 1,
        recipe_id: recipe.id,
        provider_id: recipe.provider_id,
        region: "iad",
        endpoint_url: "http://localhost:18080",
        health_path: "/health",
        attribution_code: "TEST_ATTR_CODE",
        status: "provisioning",
        inserted_at: now,
        updated_at: now
      }
      |> AgentbotCore.Repo.insert()

    IO.puts("✅ Deployment oluşturuldu: ##{deployment.id}")
    IO.puts("   Endpoint: #{deployment.endpoint_url}#{deployment.health_path}")
    IO.puts("   Attribution Code: #{deployment.attribution_code}")
    deployment
  end

  def mock_health_check(deployment_id) do
    IO.puts("\n4️⃣  Mock health check (simüle ediliyor)...")

    # Deployment'ı manuel olarak live olarak işaretle (normalde DeploymentVerifier yapar)
    AgentbotCore.Modules.Provisioning.update_deployment_status(deployment_id, "live")

    deployment = Repo.get(AgentbotCore.Modules.Provisioning.Deployment, deployment_id)
    IO.puts("✅ Deployment durumu: #{deployment.status}")
    IO.puts("   Health check başarılı (simüle edildi)!")
    deployment
  end

  def check_gap_fulfilled(gap_id) do
    IO.puts("\n5️⃣  Gap'in fulfilled durumu kontrol ediliyor...")

    gap = Repo.get(CapabilityGap, gap_id)

    if gap.fulfilled do
      IO.puts("✅ Gap fulfilled! #{gap.capability_name} capability'si artık ağda mevcut")
      true
    else
      IO.puts("⚠️  Gap henüz fulfilled değil")
      false
    end
  end
end

# Testi çalıştır
hermes_agent_id = "hermes-test-#{:rand.uniform(10000)}"

gap = TestHelper.create_pong_gap()
recipe = TestHelper.get_suggested_recipe(gap.id)

if recipe do
  deployment = TestHelper.mock_deployment(gap, recipe, hermes_agent_id)
  verified_deployment = TestHelper.mock_health_check(deployment.id)

  if verified_deployment.status == "live" do
    # Capability sağlandı
    {:ok, capability} =
      AgentbotCore.Modules.Provisioning.register_capability_from_deployment(deployment.id)

    IO.puts("🎉 Capability sağlandı: #{capability.name}")
  end

  fulfilled = TestHelper.check_gap_fulfilled(gap.id)

  # Sonuç
  IO.puts("\n" <> String.duplicate("=", 50))

  if fulfilled do
    IO.puts("🎉 E2E Test BAŞARILI! Gap→Recipe→Deploy→Verify→Fulfilled döngüsü çalışıyor!")
  else
    IO.puts("⚠️  E2E Test kısmen başarılı, bazı adımlar tamamlanamadı")
  end

  IO.puts(String.duplicate("=", 50))
else
  IO.puts("\n❌ Test başlatılamadı: recipe bulunamadı")
end

IO.puts("\n🧪 Test tamamlandı.")
