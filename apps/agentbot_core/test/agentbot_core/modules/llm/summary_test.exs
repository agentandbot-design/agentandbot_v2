defmodule AgentbotCore.Modules.LLM.SummaryTest do
  @moduledoc """
  Summary modülü testleri — event summarization.

  Anti-Crash Manifesto: Kara kutu kod yok.
  """

  use ExUnit.Case, async: true

  alias AgentbotCore.Modules.LLM.Summary

  describe "summarize/2" do
    test "new_message event için Türkçe summary üretir" do
      payload = %{
        room_id: "room-1",
        sender_name: "TestBot",
        content: "Merhaba dünya"
      }

      summary = Summary.summarize(:new_message, payload)

      assert summary.text =~ "İçerik iletildi"
      assert summary.room_id == "room-1"
      assert summary.severity == :info
    end

    test "agent_joined event için summary üretir" do
      payload = %{
        agent_id: "agent-1",
        agent_name: "HelperBot",
        room_id: "room-1"
      }

      summary = Summary.summarize(:agent_joined, payload)

      assert summary.text =~ "HelperBot"
      assert summary.event_type == "agent_joined"
      assert summary.severity == :info
    end

    test "task_failed event için error severity" do
      payload = %{
        method: "task/fail",
        room_id: "room-1"
      }

      summary = Summary.summarize(:mcp_event, payload)

      assert summary.severity == :error
    end

    test "tool_call event classification" do
      payload = %{
        method: "tools/call",
        room_id: "room-1"
      }

      summary = Summary.summarize(:mcp_event, payload)

      assert summary.event_type == "tool_call_started"
    end

    test "room_id string'e çevrilir" do
      payload = %{room_id: 42, content: "test"}
      summary = Summary.summarize(:new_message, payload)
      assert summary.room_id == "42"
    end

    test "unknown room_id 'unknown' olur" do
      payload = %{content: "test"}
      summary = Summary.summarize(:new_message, payload)
      assert summary.room_id == "unknown"
    end

    test "timestamp monotonic integer" do
      summary = Summary.summarize(:new_message, %{room_id: "r"})
      assert is_integer(summary.timestamp)
      assert summary.timestamp > 0
    end
  end

  describe "summarize_batch/1" do
    test "boş batch default döner" do
      summary = Summary.summarize_batch([])
      assert summary.event_type == "empty"
    end

    test "tek event'li batch summary döner" do
      events = [{:new_message, %{room_id: "r1", sender_name: "Bot"}}]
      summary = Summary.summarize_batch(events)

      assert summary.text =~ "İçerik iletildi"
    end

    test "çoklu event'li batch count ekler" do
      events = [
        {:new_message, %{room_id: "r1", sender_name: "Bot"}},
        {:agent_joined, %{room_id: "r1", agent_name: "Bot2"}}
      ]

      summary = Summary.summarize_batch(events)
      assert summary.text =~ "+1 olay daha"
    end
  end
end
