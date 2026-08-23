defmodule AgentbotCore.Modules.Security.AuthGate do
  @moduledoc """
  Kimlik doğrulama kapısı — tüm istekleri doğrular.

  Basit token tabanlı doğrulama (Ed25519 henüz yok).
  Phase 1'de Ed25519 imza doğrulaması eklenecek.
  """

  alias AgentbotCore.Modules.Security.AgentCredential

  @doc """
  Token doğrulama — header veya query param'den token okur.
  """
  @spec authenticate(Plug.Conn.t()) :: {:ok, map()} | {:error, String.t()}
  def authenticate(conn) do
    token = extract_token(conn)

    case token do
      nil -> {:error, "Token bulunamadı"}
      token -> verify_token(token)
    end
  end

  @doc """
  Token'ı veritabanında doğrular.
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, String.t()}
  def verify_token(token) do
    case AgentCredential.find_by_token(token) do
      nil ->
        {:error, "Geçersiz token"}

      credential ->
        # Token süresi kontrolü
        if expired?(credential) do
          {:error, "Token süresi dolmuş"}
        else
          {:ok,
           %{
             agent_id: credential.agent_id,
             agent_name: credential.agent_name,
             capabilities: credential.capabilities
           }}
        end
    end
  end

  @doc """
  Yetenek kontrolü — ajanın istenen yeteneği olup olmadığını denetler.
  """
  @spec check_capability(map(), String.t()) :: :ok | {:error, String.t()}
  def check_capability(agent_info, required_capability) do
    capabilities = Map.get(agent_info, :capabilities, [])

    if required_capability in capabilities or "admin" in capabilities do
      :ok
    else
      {:error, "Yetkiniz yok: #{required_capability}"}
    end
  end

  # Token'ı header veya query param'den çıkarır
  defp extract_token(conn) do
    conn.req_headers
    |> List.keyfind("authorization", 0)
    |> case do
      {"authorization", "Bearer " <> token} ->
        token

      _ ->
        conn.query_params["token"]
    end
  end

  # Token süresi dolmuş mu?
  defp expired?(credential) do
    case credential.expires_at do
      nil -> false
      expires_at -> DateTime.compare(expires_at, DateTime.utc_now()) == :lt
    end
  end
end
