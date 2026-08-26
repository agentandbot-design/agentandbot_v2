defmodule AgentbotCore.Modules.Security.QmSession do
  @moduledoc """
  QM portal oturum doğrulaması — qm.agentandbot.com ile ortak giriş.

  Portal `portal_session` cookie'sini Domain=agentandbot.com olarak yazar:

      body = base64url(JSON claims)
      key  = HMAC-SHA256(PORTAL_SESSION_SECRET, "portal.session.v1")
      sig  = base64url(HMAC-SHA256(key, body))
      cookie = body <> "." <> sig

  Claims: `%{"k" => "session", "sub" => email, "org" => org, "iat" => n, "exp" => n}`.
  Secret çalışma zamanında `QM_PORTAL_SESSION_SECRET` env'inden okunur.
  """

  @key_label "portal.session.v1"

  @doc """
  Cookie değerini doğrular.

  `{:ok, %{email: ..., org: ..., authenticated_at: ..., expires_at: ...}}` veya `:error`.
  """
  @spec verify(String.t() | nil) :: {:ok, map()} | :error
  def verify(token) when is_binary(token) do
    with [body, sig] <- String.split(token, ".", parts: 2),
         {:ok, expected} <- expected_signature(body),
         {:ok, got} <- decode_signature(sig),
         true <- secure_compare(got, expected),
         {:ok, claims} <- decode_claims(body),
         true <- valid_claims?(claims) do
      {:ok,
       %{
         email: claims["sub"],
         org: claims["org"],
         authenticated_at: Map.get(claims, "auth", claims["iat"]),
         expires_at: claims["exp"]
       }}
    else
      _ -> :error
    end
  end

  def verify(_), do: :error

  # base64url(body) üzerinde anahtar türetilmiş HMAC
  defp expected_signature(body) do
    sig =
      :crypto.mac(:hmac, :sha256, derived_key(), body)
      |> Base.url_encode64(padding: false)

    {:ok, sig}
  rescue
    _ -> :error
  end

  defp derived_key do
    :crypto.mac(:hmac, :sha256, session_secret(), @key_label)
  end

  defp decode_signature(sig) do
    case Base.url_decode64(sig, padding: false) do
      {:ok, raw} -> {:ok, Base.url_encode64(raw, padding: false)}
      _ -> :error
    end
  end

  defp decode_claims(body) do
    with {:ok, json} <- Base.url_decode64(body, padding: false),
         {:ok, claims} <- Jason.decode(json) do
      if is_map(claims), do: {:ok, claims}, else: :error
    else
      _ -> :error
    end
  end

  defp valid_claims?(claims) do
    now = System.os_time(:second)

    claims["k"] == "session" and
      is_binary(claims["sub"]) and claims["sub"] != "" and
      claims["org"] == expected_org() and
      is_integer(claims["iat"]) and
      is_integer(claims["exp"]) and now < claims["exp"]
  end

  # Sabit zamanlı karşılaştırma (:crypto.exor ile, bağımlılıksız)
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    diff = :crypto.exor(a, b)

    :binary.bin_to_list(diff)
    |> Enum.reduce(0, fn
      0, acc -> acc
      _, _acc -> 1
    end) == 0
  end

  defp secure_compare(_, _), do: false

  # Öncelik: app config (:agentbot_core, :qm_sso) → QM_PORTAL_SESSION_SECRET env
  defp session_secret do
    config = Application.get_env(:agentbot_core, :qm_sso, [])

    Keyword.get(config, :session_secret) ||
      System.get_env("QM_PORTAL_SESSION_SECRET") ||
      raise("QM_PORTAL_SESSION_SECRET tanımlı değil — QM ortak girişi kapalı")
  end

  defp expected_org do
    config = Application.get_env(:agentbot_core, :qm_sso, [])
    Keyword.get(config, :org, "agentandbot")
  end
end
