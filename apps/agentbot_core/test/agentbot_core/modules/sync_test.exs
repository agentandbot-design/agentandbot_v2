defmodule AgentbotCore.Modules.SyncTest do
  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Marketplace.{Task, TaskView}
  alias AgentbotCore.Modules.Sync
  alias AgentbotCore.Modules.Sync.SyncLog

  describe "dual view — tek kaynak, iki projeksiyon" do
    test "human/1 teknik detayları ve subtask'ları gizler" do
      {:ok, parent} =
        Task.create(%{
          created_by: "human:ilker",
          capability: "general",
          title: "Sync sistemi kur",
          description: "Uzun teknik açıklama satırları...",
          summary: "Kanban sync altyapısı",
          status: "in_progress",
          technical_context: %{"deps" => ["oban"], "log_ref" => "run/157"}
        })

      {:ok, _child} =
        Task.create(%{
          created_by: "human:ilker",
          capability: "general",
          title: "Alt iş 1",
          parent_id: parent.id,
          status: "completed"
        })

      parent = Task.get!(parent.id)
      human = TaskView.human(parent, parent.children)

      # İnsan görünümü: özet + progress var
      assert human.summary == "Kanban sync altyapısı"
      assert human.subtask_progress == %{done: 1, total: 1}
      # İnsan görünümü: teknik detay YOK
      refute Map.has_key?(human, :technical_context)
      refute Map.has_key?(human, :description)

      # Agent görünümü: hepsi açık
      agent = TaskView.agent(parent, parent.children)
      assert agent.technical_context["deps"] == ["oban"]
      assert agent.description =~ "teknik açıklama"
      assert [%{status: "completed"}] = agent.subtasks
      assert agent.sync_state == "in_sync"
    end

    test "summary yoksa description ilk satırı fallback" do
      {:ok, task} =
        Task.create(%{
          created_by: "human:ilker",
          capability: "general",
          title: "T",
          description: "İlk satır özet\n\nDetaylar burada"
        })

      human = TaskView.human(task, [])
      assert human.summary == "İlk satır özet"
    end
  end

  describe "sync state — AB kazanır" do
    test "mark_dirty sync_state'i dirty yapar" do
      {:ok, task} =
        Task.create(%{created_by: "human:ilker", capability: "general", title: "T"})

      # active_targets boş (sync_targets tablosu yeni) → maybe_sync no-op
      assert task.sync_state == "in_sync"

      Sync.mark_dirty(task.id)
      updated = Repo.reload!(task)
      assert updated.sync_state == "dirty"
    end

    test "apply_inbound dirty task'ta dış değişikliği reddeder (ab_won)" do
      {:ok, task} =
        Task.create(%{
          created_by: "human:ilker",
          capability: "general",
          title: "T",
          sync_metadata: %{"github" => %{"external_id" => "999"}}
        })

      Sync.mark_dirty(task.id)
      # fresh oku — apply_inbound DB'den okur, struct cache'ine değil
      Repo.get!(Task, task.id)

      assert {:conflict, :ab_won} =
               Sync.apply_inbound("github", "999", %{"status" => "completed"})

      assert [%{outcome: "ab_won", system: "github"}] = SyncLog.list_for_task(task.id)
    end

    test "apply_inbound bilinmeyen external_id'de not_found" do
      assert {:error, :not_found} = Sync.apply_inbound("github", "yok", %{})
    end
  end

  describe "adapter contract" do
    test "github adapter id/capabilities" do
      alias AgentbotCore.Modules.Sync.GithubAdapter
      assert GithubAdapter.id() == "github"
      assert GithubAdapter.capabilities().outbound
    end

    test "hermes adapter status map reverse" do
      alias AgentbotCore.Modules.Sync.SyncTarget
      sm = SyncTarget.default_status_map("hermes")
      assert sm["in_progress"] == "running"
      assert sm["completed"] == "done"
    end
  end
end
