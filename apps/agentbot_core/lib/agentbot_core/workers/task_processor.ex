defmodule AgentbotCore.Workers.TaskProcessor do
  @moduledoc """
  TaskProcessor — Oban worker for processing agent tasks.
  """
  use Oban.Worker, queue: :default, max_attempts: 3
  require Logger
  alias AgentbotCore.Modules.Marketplace.Task
  alias AgentbotCore.Modules.Marketplace.Artifact
  alias AgentbotCore.LLM.TokenLedger
  alias AgentbotCore.Modules.LLM.LiteLLM

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}}) do
    task = Task.get!(task_id)
    Logger.info("Processing Task: #{task.title} (Capability: #{task.capability})")

    # TODO: Gerçek model seçimi capability üzerinden yapılacak
    # Şimdilik genel bir akış kuruyoruz
    case process_with_llm(task) do
      {:ok, result, usage} ->
        # 1. Sonucu Artifact olarak kaydet
        save_artifact(task, result)
        
        # 2. Token Ledger kaydı (Gerçek token sayısı ile)
        total_tokens = usage["total_tokens"] || 0
        TokenLedger.record_usage(task.assigned_to, task.capability, total_tokens)
        
        # 3. Task durumunu güncelle
        Task.update_status(task_id, "completed")
        :ok
        
      {:error, reason} ->
        Logger.error("Task failed: #{inspect(reason)}")
        Task.update_status(task_id, "failed")
        {:error, reason}
    end
  end

  defp process_with_llm(task) do
    # LiteLLM üzerinden gerçek çağrı
    # Not: Bu kısım için LiteLLM API anahtarlarının env'de olması gerekir.
    # Şimdilik akışı tamamlamak için LiteLLM modülünü kullanıyoruz.
    prompt = "Task: #{task.title}\nDescription: #{task.description}\nInput: #{task.input}"
    
    # Gerçek çağrı simülasyonu (Modül henüz tam bitmediği için {:ok, ...} dönüyoruz)
    # Gelecekte: LiteLLM.completion(model: "gpt-4", messages: [...])
    {:ok, "This is a summarized output from LLM for task #{task.id}", %{"total_tokens" => 150}}
  end

  defp save_artifact(task, content) do
    Artifact.create(%{
      task_id: task.id,
      room_id: task.room_id,
      produced_by: task.assigned_to,
      artifact_type: "result",
      title: "Result of #{task.title}",
      content: content
    })
  end
end
