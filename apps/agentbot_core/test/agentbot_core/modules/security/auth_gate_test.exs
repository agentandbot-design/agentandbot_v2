defmodule AgentbotCore.Modules.Security.AuthGateTest do
  @moduledoc """
  AuthGate testleri — token doğrulama edge-case'leri.

  Anti-Crash Manifesto: Güvenlik kodu her zaman test edilmeli.
  """

  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Security.AuthGate
  alias AgentbotCore.Modules.Security.AgentCredential

  # Fake Plug.Conn for testing
  defp fake_conn(token) do
    %Plug.Conn{
      req_headers: [{"authorization", "Bearer " <> token}],
      query_params: %{}
    }
  end

  defp fake_conn_no_token do
    %Plug.Conn{req_headers: [], query_params: %{}}
  end

  defp fake_conn_query_token(token) do
    %Plug.Conn{req_headers: [], query_params: %{"token" => token}}
  end

  describe "register → authenticate flow" do
    test "credential register eder ve token ile authenticate olur" do
      {:ok, credential} = AgentCredential.register(%{
        agent_id: "test-agent-1",
        agent_name: "Test Agent",
        capabilities: ["chat.rooms", "chat.messages"]
      })

      token = credential.plain_token
      conn = fake_conn(token)

      assert {:ok, agent_info} = AuthGate.authenticate(conn)
      assert agent_info.agent_id == "test-agent-1"
      assert agent_info.agent_name == "Test Agent"
      assert "chat.rooms" in agent_info.capabilities
    end
  end

  describe "authenticate/1 failure cases" do
    test "token olmadan hata döner" do
      conn = fake_conn_no_token()
      assert {:error, "Token bulunamadı"} = AuthGate.authenticate(conn)
    end

    test "geçersiz token ile hata döner" do
      conn = fake_conn("invalid-token-12345")
      assert {:error, "Geçersiz token"} = AuthGate.authenticate(conn)
    end

    test "query param'den token okur" do
      {:ok, credential} = AgentCredential.register(%{
        agent_id: "query-agent",
        agent_name: "Query Agent"
      })

      conn = fake_conn_query_token(credential.plain_token)
      assert {:ok, _} = AuthGate.authenticate(conn)
    end
  end

  describe "verify_token/1" do
    test "süresi dolmuş token reddedilir" do
      {:ok, credential} = AgentCredential.register(%{
        agent_id: "expired-agent",
        agent_name: "Expired",
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
      })

      assert {:error, "Token süresi dolmuş"} = AuthGate.verify_token(credential.plain_token)
    end
  end

  describe "check_capability/2" do
    test "yetkili capability geçer" do
      agent_info = %{capabilities: ["chat.rooms", "chat.messages"]}
      assert :ok = AuthGate.check_capability(agent_info, "chat.rooms")
    end

    test "yetkisiz capability reddedilir" do
      agent_info = %{capabilities: ["chat.rooms"]}
      assert {:error, _} = AuthGate.check_capability(agent_info, "admin.delete")
    end

    test "admin her şeyi yapabilir" do
      agent_info = %{capabilities: ["admin"]}
      assert :ok = AuthGate.check_capability(agent_info, "anything.here")
    end
  end
end
