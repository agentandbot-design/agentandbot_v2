defmodule AgentbotCoreTest do
  use ExUnit.Case, async: true

  test "event taxonomy classify doğru çalışır" do
    alias AgentbotCore.Modules.Protocol.EventTaxonomy

    assert EventTaxonomy.classify(%{"method" => "initialize"}) == "agent_connected"
    assert EventTaxonomy.classify(%{"method" => "tools/call"}) == "tool_call_started"
    assert EventTaxonomy.classify(%{"result" => %{}}) == "tool_call_completed"
    assert EventTaxonomy.classify(%{"error" => %{}}) == "tool_call_failed"
    assert EventTaxonomy.classify(%{"content" => "merhaba"}) == "content_delivered"
    assert EventTaxonomy.classify(nil) == "unknown"
  end

  test "event taxonomy label Türkçe döndürür" do
    alias AgentbotCore.Modules.Protocol.EventTaxonomy

    assert EventTaxonomy.label("agent_connected") == "Ajan bağlandı"
    assert EventTaxonomy.label("task_completed") == "Görev tamamlandı"
  end

  test "envelope oluşturulur ve JSON'a serialize edilir" do
    alias AgentbotCore.Modules.Protocol.Envelope

    envelope = Envelope.new(type: "message", sender: "agent-1", payload: %{"msg" => "merhaba"})

    assert envelope.id != nil
    assert envelope.type == "message"
    assert envelope.sender == "agent-1"
    assert envelope.timestamp != nil

    json = Envelope.to_json(envelope)
    assert is_binary(json)

    {:ok, decoded} = Envelope.from_json(json)
    assert decoded.type == envelope.type
    assert decoded.sender == envelope.sender
  end

  test "protocol_catalog protokolleri listeler" do
    alias AgentbotCore.Modules.Protocol.ProtocolCatalog

    protocols = ProtocolCatalog.protocols()
    assert length(protocols) >= 10

    assert ProtocolCatalog.get("mcp") != nil
    assert ProtocolCatalog.get("a2a") != nil
    assert ProtocolCatalog.get("yok_bir_şey") == nil
  end
end
