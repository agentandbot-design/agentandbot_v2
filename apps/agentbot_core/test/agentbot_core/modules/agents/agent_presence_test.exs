defmodule AgentbotCore.Modules.Agents.AgentPresenceTest do
  @moduledoc """
  AgentPresence testleri — ETS tabanlı presence tracking.

  Anti-Crash Manifesto: Kara kutu kod yok.
  """

  use ExUnit.Case, async: false

  alias AgentbotCore.Modules.Agents.AgentPresence

  setup do
    # AgentPresence app supervision tree'den gelir.
    # Her test öncesi ETS tablosunu temizle.
    try do
      :ets.delete_all_objects(AgentbotCore.Modules.Agents.AgentPresence)
    rescue
      _ -> :ok
    end

    :ok
  end

  describe "track/3" do
    test "agent'ı çevrimiçi olarak işaretler" do
      :ok = AgentPresence.track("agent-1", "TestBot", "room-1")

      online = AgentPresence.list_online()
      assert length(online) == 1
      assert hd(online).agent_id == "agent-1"
      assert hd(online).agent_name == "TestBot"
      assert hd(online).room_id == "room-1"
    end

    test "global oda varsayılan" do
      :ok = AgentPresence.track("agent-2", "GlobalBot")

      online = AgentPresence.list_online()
      assert length(online) == 1
      assert hd(online).room_id == "global"
    end
  end

  describe "untrack/2" do
    test "agent'ı odadan kaldırır" do
      AgentPresence.track("agent-3", "Bot3", "room-1")
      assert AgentPresence.online?("agent-3")

      :ok = AgentPresence.untrack("agent-3", "room-1")
      refute AgentPresence.online?("agent-3")
    end
  end

  describe "list_in_room/1" do
    test "belirli odadaki agent'ları döndürür" do
      AgentPresence.track("agent-a", "BotA", "room-x")
      AgentPresence.track("agent-b", "BotB", "room-x")
      AgentPresence.track("agent-c", "BotC", "room-y")

      room_x = AgentPresence.list_in_room("room-x")
      assert length(room_x) == 2
      assert Enum.sort(Enum.map(room_x, & &1.agent_id)) == ["agent-a", "agent-b"]
    end

    test "boş oda boş liste döndürür" do
      assert AgentPresence.list_in_room("nonexistent") == []
    end
  end

  describe "count_online/0" do
    test "çevrimiçi agent sayısını döndürür" do
      assert AgentPresence.count_online() == 0

      AgentPresence.track("agent-1", "Bot1", "room-1")
      AgentPresence.track("agent-2", "Bot2", "room-2")

      assert AgentPresence.count_online() == 2
    end
  end

  describe "online?/1" do
    test "çevrimiçi agent true döndürür" do
      AgentPresence.track("agent-online", "OnlineBot")
      assert AgentPresence.online?("agent-online")
    end

    test "çevrimdışı agent false döndürür" do
      refute AgentPresence.online?("agent-offline")
    end
  end

  describe "untrack_all/1" do
    test "agent'ı tüm odalardan kaldırır" do
      AgentPresence.track("agent-multi", "MultiBot", "room-1")
      AgentPresence.track("agent-multi", "MultiBot", "room-2")
      assert AgentPresence.count_online() == 2

      :ok = AgentPresence.untrack_all("agent-multi")
      assert AgentPresence.count_online() == 0
    end
  end
end
