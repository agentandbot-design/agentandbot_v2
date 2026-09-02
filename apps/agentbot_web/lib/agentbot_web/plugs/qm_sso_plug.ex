defmodule AgentbotWeb.Plugs.QmSsoPlug do
  @moduledoc """
  QM ortak girişi plug'u — `portal_session` cookie'sini doğrular.

  qm.agentandbot.com'da açılan oturum (Domain=agentandbot.com) bu siteye de
  taşınır: geçerli cookie varsa hesabı atar (`upsert_from_email`) ve
  `conn.assigns.current_account` olarak koyar. Cookie yoksa/geçersizse
  istek anonim devam eder.
  """

  import Plug.Conn

  alias AgentbotCore.Modules.Security.Account
  alias AgentbotCore.Modules.Security.QmSession

  @cookie "portal_session"

  def init(opts), do: opts

  def call(conn, _opts) do
    case fetch_cookies(conn) |> Map.get(:cookies) |> Map.get(@cookie) do
      nil ->
        conn

      token ->
        case QmSession.verify(token) do
          {:ok, claims} ->
            case Account.upsert_from_email(claims.email) do
              {:ok, account} -> assign(conn, :current_account, account)
              _ -> assign(conn, :current_account, nil)
            end

          :error ->
            conn
        end
    end
  end
end
