defmodule AgentbotCore.Modules.Protocol.EnvelopeTest do
  @moduledoc """
  Envelope struct testleri.

  Anti-Crash Manifesto: Test edilebilirlik — her struct ve fonksiyon
  edge-case'lerle test edilmeli.
  """

  use ExUnit.Case, async: true

  alias AgentbotCore.Modules.Protocol.Envelope

  describe "new/1" do
    test "zorunlu alanlarla envelope oluşturur" do
      env = Envelope.new(type: "message", sender: "agent-1", payload: %{text: "merhaba"})

      assert %Envelope{} = env
      assert env.type == "message"
      assert env.sender == "agent-1"
      assert env.payload == %{text: "merhaba"}
      assert env.id != nil
      assert env.timestamp != nil
      assert env.content_type == "application/json"
      assert env.metadata == %{}
    end

    test "metadata ve content_type override edilebilir" do
      env =
        Envelope.new(
          type: "mcp",
          sender: "bot",
          payload: %{},
          content_type: "application/protobuf",
          metadata: %{"trace_id" => "abc"}
        )

      assert env.content_type == "application/protobuf"
      assert env.metadata == %{"trace_id" => "abc"}
    end

    test "her çağrıda benzersiz ID üretir" do
      env1 = Envelope.new(type: "m", sender: "a", payload: %{})
      env2 = Envelope.new(type: "m", sender: "a", payload: %{})

      assert env1.id != env2.id
    end
  end

  describe "to_json/1 ve from_json/1" do
    test "round-trip serialize/deserialize başarılı" do
      env =
        Envelope.new(
          type: "task",
          sender: "agent-x",
          recipient: "agent-y",
          payload: %{action: "compute", params: [1, 2, 3]},
          room_id: "room-1",
          metadata: %{"priority" => "high"}
        )

      json = Envelope.to_json(env)
      {:ok, restored} = Envelope.from_json(json)

      assert restored.type == env.type
      assert restored.sender == env.sender
      assert restored.recipient == env.recipient
      assert restored.room_id == env.room_id
      assert restored.metadata == env.metadata
    end

    test "geçersiz JSON hata döndürür" do
      assert {:error, _} = Envelope.from_json("not valid json{")
    end
  end

  describe "sign/2 ve verify_signature?/2" do
    test "imza ekler ve doğrular (placeholder)" do
      env = Envelope.new(type: "m", sender: "a", payload: %{})
      signed = Envelope.sign(env, "fake_private_key")

      assert signed.signature == "pending_ed25519"
      assert Envelope.verify_signature?(signed, "fake_public_key") == true
    end

    test "imzasız envelope doğrulanamaz" do
      env = Envelope.new(type: "m", sender: "a", payload: %{})

      assert Envelope.verify_signature?(env, "key") == false
    end
  end
end
