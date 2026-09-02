defmodule AgentbotWeb.AccountController do
  @moduledoc """
  Ortak giriş hesabı endpoint'leri.

  - `GET /me` — oturum durumu (JSON)
  - `POST /auth/logout` — paylaşılan portal_session cookie'sini temizler
  """

  use AgentbotWeb, :controller

  # Portal cookie'si Domain=agentandbot.com — apex'ten silinebilir
  @cookie_domain "agentandbot.com"

  @doc "GET /me — oturum açan hesabın e-postası"
  def show(conn, _params) do
    case conn.assigns[:current_account] do
      %AgentbotCore.Modules.Security.Account{} = account ->
        json(conn, %{
          email: account.email,
          display_name: account.display_name,
          last_signed_in_at: account.last_signed_in_at,
          login_url: nil
        })

      _ ->
        conn
        |> put_status(401)
        |> json(%{error: "unauthenticated", email: nil, login_url: qm_login_url()})
    end
  end

  # Cookie silme — Domain'li ve hostsuz iki ayrı Set-Cookie gerekir.
  # Plug aynı isimli başlığı tekilleştirdiği için (List.keystore) başlıklar
  # before_send'te doğrudan resp_headers'e yazılır.
  @clear_domain_cookie "portal_session=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Domain=" <>
                         @cookie_domain <> "; Secure; HttpOnly"
  @clear_host_cookie "portal_session=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly"

  @doc "POST /auth/logout — paylaşılan oturumu kapatır, ana sayfaya döner"
  def logout(conn, _params) do
    conn =
      register_before_send(conn, fn conn ->
        remaining = Enum.reject(conn.resp_headers, fn {k, _} -> k == "set-cookie" end)

        %{
          conn
          | resp_headers: [
              {"set-cookie", @clear_domain_cookie},
              {"set-cookie", @clear_host_cookie}
              | remaining
            ]
        }
      end)

    redirect(conn, to: "/")
  end

  defp qm_login_url do
    Keyword.get(
      Application.get_env(:agentbot_core, :qm_sso, []),
      :login_url,
      "https://qm.agentandbot.com/auth/login"
    )
  end
end
