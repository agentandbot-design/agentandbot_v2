defmodule AgentbotWeb.CouncilController do
  @moduledoc """
  Council API — bir soruyu birden fazla agent'a dağıt, görüşleri topla.

  POST /api/council — soru sor, tüm uygun agentlara dağıt
  GET /api/council/:id — konsey durumu + tüm yanıtlar
  POST /api/council/:id/respond — agent yanıtı
  GET /api/councils — tüm konseyler
  """

  use AgentbotWeb, :controller

  import Ecto.Query

  alias AgentbotCore.Modules.Council.Council
  alias AgentbotCore.Modules.Council.CouncilResponse
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

  @doc "Tüm konseyleri listele"
  def index(conn, _params) do
    councils = Council.list_recent(20)

    result =
      Enum.map(councils, fn c ->
        %{
          id: c.id,
          question: String.slice(c.question, 0, 100),
          status: c.status,
          capability: c.capability,
          response_count: Council.response_count(c.id)
        }
      end)

    json(conn, %{councils: result, count: length(result)})
  end

  @doc "Konsey detayı + tüm yanıtlar + stance dağılımı"
  def show(conn, %{"id" => id}) do
    council = Council.get_with_responses!(id)
    stance_summary = CouncilResponse.stance_summary(String.to_integer(id))

    json(conn, %{
      council: council,
      responses: council.responses,
      response_count: length(council.responses),
      stance_summary: stance_summary
    })
  end

  @doc """
  Konsey oluştur — soruyu uygun agentlara dağıt.

  Body:
  {
    "question": "Hash-chain ledger'i simdiden kurmali miyiz?",
    "capability": "code.review",          // opsiyonel — bu capability'den agentlar çağrılır
    "min_responses": 2,                    // opsiyonel, default 2
    "name": "Ilker"                        // opsiyonel
  }

  Eğer capability verilmezse tüm aktif agentlara dağıtılır.
  """
  def create(conn, params) do
    question = Map.get(params, "question", "")
    capability = Map.get(params, "capability")

    created_by =
      if Map.has_key?(conn.assigns, :agent_id),
        do: conn.assigns.agent_id,
        else: "human:#{Map.get(params, "name", "Anonim")}"

    min_responses = Map.get(params, "min_responses", 2)

    if question == "" do
      conn |> put_status(400) |> json(%{error: "question zorunlu"})
    else
      # Konseyi oluştur
      {:ok, council} =
        Council.create(%{
          question: question,
          capability: capability || "general",
          created_by: created_by,
          min_responses: min_responses,
          room_id: Map.get(params, "room_id")
        })

      # Uygun agentları bul
      agents = find_agents(capability)

      # Her agent'a PubSub ile bildirim gönder
      Enum.each(agents, fn agent ->
        AgentbotCore.PubSub.broadcast(
          "agent:#{agent.agent_id}",
          "council_invitation",
          %{
            council_id: council.id,
            question: question,
            capability: capability,
            callback_url: "/api/council/#{council.id}/respond",
            agent_id: agent.agent_id
          }
        )
      end)

      # Durumu gathering'e çek
      Council.update_status(council.id, "gathering")

      json(conn, %{
        council_id: council.id,
        question: question,
        status: "gathering",
        invited_agents: length(agents),
        agents: Enum.map(agents, & &1.agent_id),
        min_responses: min_responses,
        message: "Soru #{length(agents)} agent'a dağıtıldı. Yanıtlar toplanıyor.",
        tracking_url: "/api/council/#{council.id}"
      })
    end
  end

  @doc """
  Agent konsey'e yanıt verir.

  Body:
  {
    "content": "Katılıyorum çünkü...",
    "stance": "support",          // support, oppose, neutral, alternative
    "confidence": 0.8             // 0.0 - 1.0
  }
  """
  def respond(conn, %{"id" => council_id} = params) do
    agent_id = Map.get(conn.assigns, :agent_id, "unknown")
    agent_name = Map.get(Map.get(conn.assigns, :agent_info, %{}), :agent_name, agent_id)
    content = Map.get(params, "content", "")
    stance = Map.get(params, "stance", "neutral")
    confidence = Map.get(params, "confidence")

    if content == "" do
      conn |> put_status(400) |> json(%{error: "content zorunlu"})
    else
      cid = String.to_integer(council_id)

      # Aynı agent iki kez yanıt veremez
      if CouncilResponse.already_responded?(cid, agent_id) do
        conn |> put_status(409) |> json(%{error: "Bu agent zaten yanıt verdi"})
      else
        {:ok, response} =
          CouncilResponse.respond(%{
            council_id: cid,
            agent_id: agent_id,
            agent_name: agent_name,
            content: content,
            stance: stance,
            confidence: confidence && parse_decimal(confidence)
          })

        # Yeterli yanıt geldi mi?
        count = Council.response_count(cid)
        council = Repo.get!(Council, cid)

        status = if count >= council.min_responses, do: "ready", else: "gathering"

        if status == "ready" and council.status != "synthesized" do
          Council.update_status(cid, "ready")
        end

        json(conn, %{
          response_id: response.id,
          status: "accepted",
          total_responses: count,
          council_status: status,
          message:
            if(status == "ready",
              do: "Yeterli yanıt toplandı. Sentez için hazır.",
              else: "Yanıt kaydedildi. Daha fazla yanıt bekleniyor."
            )
        })
      end
    end
  end

  @doc """
  Konsey sentezi — toplanan yanıtların özeti.

  Body:
  {
    "synthesis": "3 agent yanıtladı. 2 support, 1 oppose..."
  }
  """
  def synthesize(conn, %{"id" => council_id} = params) do
    synthesized_by = Map.get(conn.assigns, :agent_id, "human")
    synthesis = Map.get(params, "synthesis", "")

    case Council.update_status(String.to_integer(council_id), "synthesized",
           synthesis: synthesis,
           synthesized_by: synthesized_by
         ) do
      {:ok, council} ->
        json(conn, %{
          council_id: council.id,
          status: "synthesized",
          synthesis: synthesis,
          message: "Konsey sentezlendi ve kapatıldı."
        })

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Sentez başarısız"})
    end
  end

  # ── Helpers ──

  defp find_agents(nil) do
    # Capability verilmedi → tüm aktif agentları bul
    AgentCredential
    |> where([c], c.is_active == true and c.executor_type == "agent")
    |> Repo.all()
  end

  defp find_agents(capability) do
    # Capability'e sahip agentları bul
    providers = Capability.providers(capability)

    # AgentCredential'dan tam kayıtları getir
    agent_ids = Enum.map(providers, & &1.agent_id)

    if agent_ids == [] do
      # Yoksa tüm agentları al
      AgentCredential
      |> where([c], c.is_active == true and c.executor_type == "agent")
      |> Repo.all()
    else
      AgentCredential
      |> where([c], c.agent_id in ^agent_ids and c.is_active == true)
      |> Repo.all()
    end
  end

  defp parse_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp parse_decimal(val) when is_integer(val), do: Decimal.new(val)

  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {dec, _} -> dec
      :error -> nil
    end
  end
end
