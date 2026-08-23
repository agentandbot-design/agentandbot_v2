defmodule AgentbotWeb.CapabilityController do
  @moduledoc """
  Capability Registry API — listele, keşfet, sağla, gap'leri gör.
  """

  use AgentbotWeb, :controller

  import Ecto.Query

  alias AgentbotCore.Modules.Registry.AgentCapability
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

  # ── CAPABILITY CRUD ─────────────────────────────────────

  @doc "Tüm capability'leri listele"
  def index(conn, params) do
    capabilities =
      case params do
        %{"category" => cat} when cat != "" -> Capability.list_by_category(cat)
        _ -> Capability.list_active()
      end

    json(conn, %{capabilities: capabilities, count: length(capabilities)})
  end

  @doc "Capability detayı + provider'ları"
  def show(conn, %{"name" => name}) do
    case Capability.get_by_name(name) do
      nil ->
        conn |> put_status(404) |> json(%{error: "Capability bulunamadı"})

      capability ->
        providers = Capability.providers(name)

        json(conn, %{
          capability: capability,
          providers: providers,
          provider_count: length(providers)
        })
    end
  end

  # ── DISCOVERY ───────────────────────────────────────────

  @doc "Capability'ye sahip agent'ları bul — evidence-based ranking"
  def discover(conn, %{"capability" => capability_name}) do
    case Capability.get_by_name(capability_name) do
      nil ->
        # Capability yok → gap kaydet
        CapabilityGap.record_request(capability_name)

        conn
        |> put_status(404)
        |> json(%{
          capability: capability_name,
          found: false,
          message: "Bu capability sağlayan agent yok. Talep gap olarak kaydedildi.",
          gap: true
        })

      _capability ->
        providers = Capability.providers(capability_name)

        if providers == [] do
          # Capability var ama provider yok → gap
          CapabilityGap.record_request(capability_name)

          conn
          |> put_status(404)
          |> json(%{
            capability: capability_name,
            found: false,
            message: "Capability tanımlı ama sağlayan agent yok. Gap kaydedildi.",
            gap: true
          })
        else
          json(conn, %{
            capability: capability_name,
            found: true,
            providers: providers,
            count: length(providers)
          })
        end
    end
  end

  def discover(conn, _params) do
    conn |> put_status(400) |> json(%{error: "capability parametresi zorunlu"})
  end

  # ── PROVIDER (Agent capability sağlama) ─────────────────

  @doc "Agent bir capability sağladığını bildirir (register as provider)"
  def provide(conn, %{"capability" => capability_name}) do
    agent_id = conn.assigns.agent_id

    # Agent'ın credential'ını bul (duplicate kayıtlar olabilir, ilk aktif olanı al)
    credential =
      AgentCredential
      |> where([c], c.agent_id == ^agent_id and c.is_active == true)
      |> order_by([c], desc: c.inserted_at)
      |> limit(1)
      |> Repo.one()

    if is_nil(credential) do
      conn |> put_status(404) |> json(%{error: "Agent credential bulunamadı"})
    else
      {:ok, capability} =
        Capability.find_or_create(capability_name, %{
          description: conn.body_params["description"],
          category: conn.body_params["category"]
        })

      {:ok, _agent_cap} = AgentCapability.provide(credential.id, capability.id)

      # Gap varsa dolduruldu olarak işaretle
      CapabilityGap.fulfill(capability_name, agent_id)

      conn
      |> put_status(201)
      |> json(%{
        status: "provided",
        capability: capability.name,
        agent_id: agent_id,
        message: "Agent artık bu capability'yi sağlıyor"
      })
    end
  end

  # ── GAP TRACKING ────────────────────────────────────────

  @doc "En çok talep edilen ama karşılanamayan capability'ler"
  def top_gaps(conn, _params) do
    gaps = CapabilityGap.list_top_gaps(20)

    json(conn, %{
      gaps: gaps,
      count: length(gaps),
      message: "Bu capability'ler talep ediliyor ama sağlayıcısı yok"
    })
  end

  @doc "Tüm doldurulmamış gap'ler"
  def unfulfilled_gaps(conn, _params) do
    gaps = CapabilityGap.list_unfulfilled()
    json(conn, %{gaps: gaps, count: length(gaps)})
  end
end
