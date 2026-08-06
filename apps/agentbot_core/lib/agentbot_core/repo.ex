defmodule AgentbotCore.Repo do
  @moduledoc """
  Ecto repository — PostgreSQL veritabanı bağlantısı.

  Tüm schema'lar bu repo üzerinden sorgulanır.
  """

  use Ecto.Repo,
    otp_app: :agentbot_core,
    adapter: Ecto.Adapters.Postgres
end
