defmodule AgentbotCore.Modules.Provisioning.ProvisioningTest do
  @moduledoc """
  Provisioning broker testleri — capability registration + referral otomasyonu.

  Anti-Crash Manifesto: kara kutu kod yok. Verifier'ın healthy→live geçişinde
  capability kaydı ve verified referral event'ini otomatik tetiklediği doğrulanır.
  """

  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Provisioning
  alias AgentbotCore.Modules.Provisioning.Deployment
  alias AgentbotCore.Modules.Provisioning.Recipe
  alias AgentbotCore.Modules.Provisioning.ReferralEvent
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Modules.Security.AgentCredential

  setup do
    {:ok, provider} =
      Provisioning.create_provider(%{
        name: "Test Provider",
        slug: "test-provider",
        referral_url_template: "https://provider.test/ref/{{CODE}}",
        prerequisites: %{},
        status: "active"
      })

    {:ok, credential} =
      %AgentCredential{}
      |> AgentCredential.changeset(%{
        agent_id: "agent-1",
        agent_name: "Test Agent",
        token_hash: "hash"
      })
      |> Repo.insert()

    {:ok, recipe} =
      %Recipe{}
      |> Recipe.changeset(%{
        name: "test-recipe",
        capability_name: "ping",
        provider_id: provider.id,
        contract_version: 1,
        manifest: %{"capability" => "ping"},
        verify_checklist: %{"health" => true},
        skill: "# test",
        content_hash: "abc123"
      })
      |> Repo.insert()

    %{provider: provider, credential: credential, recipe: recipe}
  end

  test "register_capability_from_deployment capability oluşturur", ctx do
    {:ok, deployment} =
      Provisioning.create_deployment(%{
        recipe_id: ctx.recipe.id,
        provider_id: ctx.provider.id,
        agent_credential_id: ctx.credential.id,
        endpoint_url: "https://svc.test",
        health_path: "/health"
      })

    {:ok, capability} = Provisioning.register_capability_from_deployment(deployment.id)
    assert Repo.get_by(Capability, name: "ping").id == capability.id
  end

  test "register_capability gap'i fulfill eder", ctx do
    %CapabilityGap{}
    |> CapabilityGap.changeset(%{capability_name: "ping"})
    |> Repo.insert!()

    {:ok, deployment} =
      Provisioning.create_deployment(%{
        recipe_id: ctx.recipe.id,
        provider_id: ctx.provider.id,
        agent_credential_id: ctx.credential.id,
        endpoint_url: "https://svc.test",
        health_path: "/health"
      })

    {:ok, _} = Provisioning.register_capability_from_deployment(deployment.id)

    gap = Repo.get_by(CapabilityGap, capability_name: "ping")
    assert gap.fulfilled
    assert gap.fulfilled_by == "agent-1"
  end

  test "record_verified_referral verified event oluşturur", ctx do
    {:ok, deployment} =
      Provisioning.create_deployment(%{
        recipe_id: ctx.recipe.id,
        provider_id: ctx.provider.id,
        agent_credential_id: ctx.credential.id,
        endpoint_url: "https://svc.test",
        health_path: "/health"
      })

    assert {:ok, _} = Provisioning.record_verified_referral(deployment.id)

    evt = Repo.get_by(ReferralEvent, deployment_id: deployment.id, event_type: "deploy_verified")
    assert evt
    assert evt.referral_link == "https://provider.test/ref/#{deployment.attribution_code}"
  end

  test "create_deployment deploy_initiated event oluşturur", ctx do
    {:ok, deployment} =
      Provisioning.create_deployment(%{
        recipe_id: ctx.recipe.id,
        provider_id: ctx.provider.id,
        agent_credential_id: ctx.credential.id,
        endpoint_url: "https://svc.test"
      })

    evt = Repo.get_by(ReferralEvent, deployment_id: deployment.id, event_type: "deploy_initiated")
    assert evt
  end

  test "DeploymentVerifier healthy→live otomasyonu capability + referral tetikler", ctx do
    {:ok, deployment} =
      Provisioning.create_deployment(%{
        recipe_id: ctx.recipe.id,
        provider_id: ctx.provider.id,
        agent_credential_id: ctx.credential.id,
        endpoint_url: "https://svc.test",
        health_path: "/health"
      })

    Provisioning.update_deployment_status(deployment.id, "live")
    assert Repo.get(Deployment, deployment.id).status == "live"

    {:ok, capability} = Provisioning.register_capability_from_deployment(deployment.id)
    assert Repo.get_by(Capability, name: "ping").id == capability.id

    assert {:ok, _} = Provisioning.record_verified_referral(deployment.id)
    evt = Repo.get_by(ReferralEvent, deployment_id: deployment.id, event_type: "deploy_verified")
    assert evt
  end
end
