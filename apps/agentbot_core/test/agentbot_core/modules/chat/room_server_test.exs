defmodule AgentbotCore.Modules.Chat.RoomServerTest do
  @moduledoc """
  RoomServer testleri — pause/resume, join/leave, state management.

  Anti-Crash Manifesto: Kara kutu kod yok.
  """

  use ExUnit.Case, async: false

  alias AgentbotCore.Modules.Chat.RoomServer

  setup do
    # PubSub ve Registry app supervision tree'den gelir
    # Test odası başlat
    {:ok, _pid} = RoomServer.start_link(room_id: "test-room-1", room_name: "Test Odası")

    :ok
  end

  describe "start_link/1" do
    test "oda süreci başlar" do
      {:ok, _pid} = RoomServer.start_link(room_id: "test-room-2", room_name: "Oda 2")
      state = RoomServer.get_state("test-room-2")
      assert state.room_id == "test-room-2"
      assert state.room_name == "Oda 2"
    end
  end

  describe "join_agent/3 and leave_agent/2" do
    test "agent katılır ve state'e eklenir" do
      :ok = RoomServer.join_agent("test-room-1", "agent-1", "TestBot")

      state = RoomServer.get_state("test-room-1")
      assert Map.has_key?(state.agents, "agent-1")
      assert state.agents["agent-1"].name == "TestBot"
    end

    test "agent ayrılır ve state'den kaldırılır" do
      RoomServer.join_agent("test-room-1", "agent-1", "TestBot")
      RoomServer.leave_agent("test-room-1", "agent-1")

      state = RoomServer.get_state("test-room-1")
      refute Map.has_key?(state.agents, "agent-1")
    end
  end

  describe "pause/1 and resume/1" do
    test "oda duraklatıldığında durum paused olur" do
      :ok = RoomServer.pause("test-room-1")
      state = RoomServer.get_state("test-room-1")
      assert state.status == :paused
    end

    test "oda devam ettirildiğinde durum active olur" do
      RoomServer.pause("test-room-1")
      :ok = RoomServer.resume("test-room-1")
      state = RoomServer.get_state("test-room-1")
      assert state.status == :active
    end

    test "paused durumunda mesajlar buffer'lanır" do
      RoomServer.pause("test-room-1")

      # Buffer'a mesaj ekle
      RoomServer.send_message("test-room-1", %{content: "buffered msg", sender_id: "agent-1"})

      state = RoomServer.get_state("test-room-1")
      assert length(state.buffer) == 1
    end

    test "resume yapıldığında buffer temizlenir" do
      RoomServer.pause("test-room-1")
      RoomServer.send_message("test-room-1", %{content: "buffered msg", sender_id: "agent-1"})

      :ok = RoomServer.resume("test-room-1")

      state = RoomServer.get_state("test-room-1")
      assert state.buffer == []
      assert state.message_count == 1
    end
  end

  describe "send_message/2 active durumunda" do
    test "mesaj gönderildiğinde sayacı artırır" do
      initial = RoomServer.get_state("test-room-1")
      initial_count = initial.message_count

      RoomServer.send_message("test-room-1", %{content: "merhaba", sender_id: "agent-1"})

      # cast async olduğu için kısa bekle
      Process.sleep(50)

      final = RoomServer.get_state("test-room-1")
      assert final.message_count == initial_count + 1
    end
  end
end
