defmodule AgentbotCore.Repo.Migrations.CreateAgentCapabilities do
  @moduledoc """
  Agent capability manifest — agent'in ne yapabildiğini bildirir.
  Bauhaus: sadece gerekli alanlar.
  """

  use Ecto.Migration

  def change do
    # Agent'lara capability bildirimi için metadata ekle
    # capabilities array zaten var, biz sadece index ekliyoruz
    # Discovery için GIN index — capability array search
    execute "CREATE INDEX IF NOT EXISTS agent_credentials_capabilities_idx ON agent_credentials USING GIN (capabilities)"

    # Agent'a protocol bilgisi ekle (mcp, a2a, http, ws)
    alter table(:agent_credentials) do
      add :protocols, {:array, :string}, default: ["rest"]
      add :description, :string
    end
  end
end
