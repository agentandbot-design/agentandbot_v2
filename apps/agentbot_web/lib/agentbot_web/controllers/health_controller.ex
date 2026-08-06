defmodule AgentbotWeb.HealthController do
  @moduledoc """
  Sağlık kontrolü — servis durumunu raporlar.
  """

  use AgentbotWeb, :controller

  def index(conn, _params) do
    # DB bağlantı kontrolü
    db_status = try do
      AgentbotCore.Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end

    json(conn, %{
      status: "healthy",
      version: "0.1.0",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      database: db_status,
      services: %{
        core: "up",
        web: "up",
        pubsub: "up"
      }
    })
  end
end
