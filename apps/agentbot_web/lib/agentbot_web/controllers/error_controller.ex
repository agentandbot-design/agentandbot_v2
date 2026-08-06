defmodule AgentbotWeb.ErrorController do
  @moduledoc """
  Hata yakalayıcı — 404 ve diğer hatalar.
  """

  use AgentbotWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{error: "Endpoint bulunamadı", status: 404})
  end
end
