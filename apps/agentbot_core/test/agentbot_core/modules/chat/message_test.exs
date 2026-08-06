defmodule AgentbotCore.Modules.Chat.MessageTest do
  @moduledoc "Message schema testleri — DB entegrasyonlu"

  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Chat.{Room, Message}

  setup do
    {:ok, room} = Room.create(%{name: "Test Room"})
    {:ok, room: room}
  end

  describe "changeset/2" do
    test "geçerli attributelerle geçerli", %{room: room} do
      changeset = Message.changeset(%Message{}, %{
        room_id: room.id,
        sender_id: "agent-1",
        content: "Merhaba"
      })
      assert changeset.valid?
    end

    test "content olmadan geçersiz", %{room: room} do
      changeset = Message.changeset(%Message{}, %{
        room_id: room.id,
        sender_id: "agent-1"
      })
      refute changeset.valid?
    end

    test "sender_id olmadan geçersiz", %{room: room} do
      changeset = Message.changeset(%Message{}, %{
        room_id: room.id,
        content: "test"
      })
      refute changeset.valid?
    end
  end

  describe "create/1 ve list_by_room/2" do
    test "mesaj oluşturur ve listeler", %{room: room} do
      {:ok, msg} = Message.create(%{
        room_id: room.id,
        sender_id: "agent-1",
        sender_name: "Agent One",
        content: "Test mesajı"
      })

      assert msg.id != nil
      assert msg.content == "Test mesajı"

      messages = Message.list_by_room(room.id)
      assert length(messages) == 1
      assert hd(messages).content == "Test mesajı"
    end

    test "en son mesaj önce gelir", %{room: room} do
      {:ok, _} = Message.create(%{room_id: room.id, sender_id: "a", content: "ilk"})
      :timer.sleep(1100)
      {:ok, _} = Message.create(%{room_id: room.id, sender_id: "b", content: "ikinci"})

      messages = Message.list_by_room(room.id)
      assert hd(messages).content == "ikinci"
    end

    test "limit çalışır", %{room: room} do
      for i <- 1..10 do
        Message.create(%{room_id: room.id, sender_id: "a", content: "msg-#{i}"})
        :timer.sleep(5)
      end

      messages = Message.list_by_room(room.id, 5)
      assert length(messages) == 5
    end
  end
end
