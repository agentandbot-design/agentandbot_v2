defmodule AgentbotWeb.TaskController do
  @moduledoc """
  Task API — oluştur, keşfet, delege et, tamamla.

  Kopukluk giderildi: Task ↔ Capability Registry bağlı.
  Task create → auto-discover → auto-delegate (tek provider) veya gap kaydet.
  Artifact submit → stats güncelle (record_completion).
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Execution.Dispatcher
  alias AgentbotCore.Modules.Marketplace.Artifact
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Registry.AgentCapability
  alias AgentbotCore.Modules.Registry.Capability
  alias AgentbotCore.Modules.Registry.CapabilityGap
  alias AgentbotCore.Modules.Security.AgentCredential
  alias AgentbotCore.Repo

  import Ecto.Query

  # ── LIST ──────────────────────────────────────────

  @doc "Tüm task'ları listele (filtre: status, capability)"
  def index(conn, params) do
    tasks =
      case params do
        %{"status" => status} when status != "" ->
          Task
          |> where([t], t.status == ^status)
          |> order_by([t], desc: t.inserted_at)
          |> Repo.all()

        %{"capability" => cap} when cap != "" ->
          Task.list_open_by_capability(cap)

        _ ->
          Task |> order_by([t], desc: t.inserted_at) |> Repo.all()
      end

    json(conn, %{tasks: tasks})
  end

  @doc "Task detayı + artifact'ları"
  def show(conn, %{"id" => id}) do
    task = Task.get!(id)
    artifacts = Artifact.list_by_task(id)
    json(conn, %{task: task, artifacts: artifacts})
  end

  # ── CREATE + AUTO-DISCOVER + AUTO-DELEGATE ─────────

  @doc """
  Task oluştur → otomatik discovery → otomatik delegate.

  Akış:
  1. Task DB'ye kaydet (status: open)
  2. Capability.providers ile sağlayıcıları ara
  3. Tek provider varsa → otomatik ata (status: assigned)
  4. Provider yoksa → CapabilityGap kaydet (status: open, gap: true)
  """
  def create(conn, params) do
    created_by = Map.get(conn.assigns, :agent_id, "human")
    capability_name = params["capability"]

    case Task.create(%{
           room_id: params["room_id"],
           created_by: created_by,
           capability: capability_name,
           title: params["title"],
           description: params["description"],
           input: params["input"] && Jason.encode!(params["input"]),
           priority: params["priority"] || 0
         }) do
      {:ok, task} ->
        # ── AUTO-DISCOVER ──
        result = auto_discover_and_delegate(task)

        conn
        |> put_status(201)
        |> json(%{
          task: Task.get!(task.id),
          discovery: result.discovery,
          auto_assigned: result.auto_assigned,
          providers: result.providers,
          gap: result.gap
        })

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  # ── MANUAL ASSIGN ─────────────────────────────────

  @doc "Task'ı manuel olarak agent'a ata"
  def assign(conn, %{"task_id" => task_id, "agent_id" => agent_id}) do
    case Task.assign(task_id, agent_id) do
      {:ok, task} ->
        json(conn, %{task: task, status: "assigned"})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Atama başarısız"})
    end
  end

  # ── STATUS UPDATE ─────────────────────────────────

  @doc "Agent task durumunu güncelle"
  def update_status(conn, %{"task_id" => task_id, "status" => status}) do
    case Task.update_status(task_id, status) do
      {:ok, task} ->
        json(conn, %{task: task})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Durum güuncellenemedi"})
    end
  end

  @doc "Task'ı claim et (race condition koruması)"
  def claim(conn, %{"task_id" => task_id}) do
    agent_id = conn.assigns.agent_id

    case Task.claim(task_id, agent_id) do
      {:ok, task} ->
        json(conn, %{task: task, status: "claimed", claimed_by: agent_id})

      {:error, reason} ->
        conn |> put_status(409) |> json(%{error: reason, status: "claim_failed"})
    end
  end

  # ── ARTIFACT SUBMIT + STATS UPDATE ────────────────

  @doc """
  Agent artifact submit → task completed + stats güncelle.

  Kopukluk giderildi: Artifact üretince AgentCapability.record_completion
  çağrılır. Success rate, tasks_completed güncellenir.
  """
  def submit_artifact(conn, params) do
    produced_by = Map.get(conn.assigns, :agent_id, "unknown")
    task_id = params["task_id"]

    case Artifact.create(%{
           task_id: task_id,
           room_id: params["room_id"],
           produced_by: produced_by,
           artifact_type: params["artifact_type"] || "report",
           title: params["title"],
           content: params["content"],
           metadata: params["metadata"] && Jason.encode!(params["metadata"])
         }) do
      {:ok, artifact} ->
        # Task'ı tamamlandı olarak işaretle
        Task.update_status(task_id, "completed")

        # ── STATS GÜNCELLE ──
        # Agent'ın bu capability için başarı istatistiğini güncelle
        task = Task.get!(task_id)
        update_agent_stats(task, produced_by, true)

        conn |> put_status(201) |> json(%{artifact: artifact, status: "produced"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  # ── VERIFY ARTIFACT ───────────────────────────────

  @doc "Artifact'ı doğrula (human verification)"
  def verify_artifact(conn, %{"id" => artifact_id}) do
    verified_by = Map.get(conn.assigns, :agent_id, "human")

    case Artifact.verify(artifact_id, verified_by) do
      {:ok, artifact} ->
        json(conn, %{artifact: artifact, status: "verified"})

      {:error, _} ->
        conn |> put_status(422) |> json(%{error: "Doğrulama başarısız"})
    end
  end

  # ── HUMAN ENTRY — auth yok, insan da gelir ═══════

  @doc """
  İnsan derdini söyler → sistem executor bulur.

  POST /api/request
  Body: { "need": "20K gorseli resize et", "name": "İlker" (opsiyonel) }

  Sistem:
  1. need'i capability'ye eşler (şimdilik direkt capability alanı, sonra NLP)
  2. Capability ara → bulursa auto-delegate + dispatch
  3. Bulamazsa → gap kaydet
  4. Task ID döner — insan status'u takip eder
  """
  def human_request(conn, params) do
    need = Map.get(params, "need", "")
    name = Map.get(params, "name", "Anonim")
    capability = Map.get(params, "capability")
    title = String.slice(need, 0, 100)

    if need == "" do
      conn |> put_status(400) |> json(%{error: "need alani zorunlu"})
    else
      # Eğer capability belirtilmemişse, need'in ilk kelimesini kullan
      # (geçici — sonra NLP ile capability extraction)
      cap = capability || guess_capability(need)

      case Task.create(%{
             created_by: "human:#{name}",
             capability: cap,
             title: title,
             description: need,
             room_id: Map.get(params, "room_id")
           }) do
        {:ok, task} ->
          result = auto_discover_and_delegate(task)

          conn
          |> put_status(201)
          |> json(%{
            task_id: task.id,
            message: format_human_response(cap, result),
            capability: cap,
            status: Task.get!(task.id).status,
            discovery: result.discovery,
            tracking_url: "/api/tasks/#{task.id}"
          })

        {:error, changeset} ->
          conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
      end
    end
  end

  # need metninden capability tahmin et (basit keyword matching)
  # Sonra: NLP / LLM ile geliştirilecek
  defp guess_capability(need) do
    need_lower = String.downcase(need)

    cond do
      String.contains?(need_lower, ["resize", "image", "gorsel", "foto"]) -> "image.resize"
      String.contains?(need_lower, ["code", "kod", "review", "güvenlik"]) -> "code.review"
      String.contains?(need_lower, ["pdf", "belge", "document"]) -> "document.process"
      String.contains?(need_lower, ["report", "rapor", "analiz"]) -> "report.generate"
      String.contains?(need_lower, ["sap", "fatura", "mutabakat"]) -> "sap.fi"
      String.contains?(need_lower, ["translate", "çevir", "tercüme"]) -> "translate"
      String.contains?(need_lower, ["github", "pr", "merge"]) -> "github.pr.read"
      true -> "general"
    end
  end

  defp format_human_response(cap, result) do
    case result.discovery do
      "found" ->
        "İşini yapabilecek executor bulundu: #{cap}. Task oluşturuldu ve atandı."

      "gap" ->
        "Bu iş için henüz executor yok (#{cap}). Talebin kaydedildi — birisi doldurunca haber verilecek."
    end
  end

  # ── HELPERS ───────────────────────────────────────

  # Task oluştuktan sonra capability discovery + auto-delegate + dispatch
  defp auto_discover_and_delegate(task) do
    case Capability.get_by_name(task.capability) do
      nil ->
        # Capability yok → gap kaydet
        CapabilityGap.record_request(task.capability)
        %{discovery: "gap", auto_assigned: false, providers: [], gap: true}

      _capability ->
        # Capability var → sağlayıcıları getir
        providers = Capability.providers(task.capability)

        case providers do
          [] ->
            # Provider yok → gap
            CapabilityGap.record_request(task.capability)
            %{discovery: "gap", auto_assigned: false, providers: [], gap: true}

          [provider | _rest] ->
            # Provider var → en iyi sağlayıcıya ata (ilk = en yüksek tasks_completed)
            {:ok, _task} = Task.assign(task.id, provider.agent_id)

            # ── DISPATCH ──
            # Executor'ı çağır — task artık in_progress
            dispatch_result = Dispatcher.dispatch(task.id)

            %{
              discovery: "found",
              auto_assigned: true,
              providers: Enum.map(providers, &strip_provider/1),
              gap: false,
              dispatch: dispatch_result
            }
        end
    end
  end

  # Agent stats güncelle — AgentCapability.record_completion
  defp update_agent_stats(task, agent_id, success) do
    # Agent'ın credential'ını bul
    credential =
      AgentCredential
      |> where([c], c.agent_id == ^agent_id and c.is_active == true)
      |> order_by([c], desc: c.inserted_at)
      |> limit(1)
      |> Repo.one()

    if credential do
      # Capability'yi bul (veya oluştur)
      {:ok, capability} = Capability.find_or_create(task.capability)

      # Provider ilişkisi yoksa oluştur
      AgentCapability.provide(credential.id, capability.id)

      # Stats güncelle
      AgentCapability.record_completion(credential.id, capability.id, success)
    end
  end

  defp strip_provider(p) do
    %{
      agent_id: p.agent_id,
      agent_name: p.agent_name,
      executor_type: p.executor_type,
      endpoint: p.endpoint,
      verified: p.verified,
      tasks_completed: p.tasks_completed,
      success_rate: p.success_rate && Decimal.to_string(p.success_rate)
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
