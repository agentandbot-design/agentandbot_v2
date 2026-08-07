defmodule AgentbotCore.Modules.Chat.ApprovalRequestTest do
  @moduledoc """
  ApprovalRequest testleri — onay talebi CRUD + sorgular.

  Anti-Crash Manifesto: Kara kutu kod yok.
  """

  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Chat.{ApprovalRequest, Room}

  setup do
    {:ok, room} = Room.create(%{name: "Test Odası", description: "Test açıklaması"})
    {:ok, room: room}
  end

  describe "create/1" do
    test "geçerli attributelerle onay talebi oluşturur", %{room: room} do
      attrs = %{
        room_id: room.id,
        requester_id: "agent-1",
        requester_name: "TestBot",
        title: "Dosya silme izni",
        description: "/tmp/old_logs dizinini silmek istiyorum"
      }

      {:ok, approval} = ApprovalRequest.create(attrs)

      assert approval.requester_id == "agent-1"
      assert approval.title == "Dosya silme izni"
      assert approval.status == "pending"
      assert approval.room_id == room.id
    end

    test "requester_id olmadan geçersiz" do
      attrs = %{title: "Test"}
      changeset = ApprovalRequest.changeset(%ApprovalRequest{}, attrs)
      refute changeset.valid?
    end

    test "title olmadan geçersiz" do
      attrs = %{requester_id: "agent-1"}
      changeset = ApprovalRequest.changeset(%ApprovalRequest{}, attrs)
      refute changeset.valid?
    end
  end

  describe "approve/3" do
    test "onay talebini approved durumuna getirir", %{room: room} do
      {:ok, approval} = ApprovalRequest.create(%{
        room_id: room.id,
        requester_id: "agent-1",
        title: "Test izni"
      })

      {:ok, approved} = ApprovalRequest.approve(approval.id, "human-admin", "Tamam, yap")

      assert approved.status == "approved"
      assert approved.resolved_by == "human-admin"
      assert approved.resolution_note == "Tamam, yap"
    end
  end

  describe "reject/3" do
    test "onay talebini rejected durumuna getirir", %{room: room} do
      {:ok, approval} = ApprovalRequest.create(%{
        room_id: room.id,
        requester_id: "agent-1",
        title: "Tehlikeli işlem"
      })

      {:ok, rejected} = ApprovalRequest.reject(approval.id, "human-admin")

      assert rejected.status == "rejected"
      assert rejected.resolved_by == "human-admin"
    end
  end

  describe "list_pending_by_room/1" do
    test "odadaki beklemedeki talepleri listeler", %{room: room} do
      ApprovalRequest.create(%{room_id: room.id, requester_id: "agent-1", title: "İzin 1"})
      ApprovalRequest.create(%{room_id: room.id, requester_id: "agent-2", title: "İzin 2"})

      pending = ApprovalRequest.list_pending_by_room(room.id)
      assert length(pending) == 2
    end

    test "onaylanan talepleri listelemez", %{room: room} do
      {:ok, a1} = ApprovalRequest.create(%{room_id: room.id, requester_id: "agent-1", title: "İzin 1"})
      ApprovalRequest.approve(a1.id, "human")

      pending = ApprovalRequest.list_pending_by_room(room.id)
      assert pending == []
    end

    test "boş oda boş liste döndürür" do
      assert ApprovalRequest.list_pending_by_room(99_999) == []
    end
  end

  describe "count_pending/0" do
    test "toplam beklemedeki onay sayısını döndürür", %{room: room} do
      ApprovalRequest.create(%{room_id: room.id, requester_id: "agent-1", title: "İzin 1"})
      ApprovalRequest.create(%{room_id: room.id, requester_id: "agent-2", title: "İzin 2"})

      assert ApprovalRequest.count_pending() >= 2
    end
  end
end
