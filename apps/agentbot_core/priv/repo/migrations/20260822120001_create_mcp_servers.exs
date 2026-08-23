defmodule AgentbotCore.Repo.Migrations.CreateMcpServers do
  @moduledoc """
  MCP Registry — merkezi MCP sunucu yönetimi.

  Public MCP'ler her agent görebilir.
  Private MCP'ler (API key gömülü) sadece yetkili agent'lar.
  """
  use Ecto.Migration

  def change do
    create table(:mcp_servers) do
      # benzersiz isim (activepieces, filesystem, ...)
      add(:name, :string, null: false)
      # ne işe yarar
      add(:description, :string)
      # http | stdio
      add(:transport_type, :string, null: false, default: "http")
      # HTTP transport URL
      add(:url, :string)
      # stdio transport command (npx, uvx, ...)
      add(:command, :string)
      # stdio args (JSON array)
      add(:args, :text)
      # encrypted JSON — auth credentials (private)
      add(:headers, :text)
      # public | private
      add(:visibility, :string, null: false, default: "public")
      # virgülle ayrılmış etiketler
      add(:tags, :string)
      # private MCP'lerin sahibi
      add(:owner_agent_id, :string)
      add(:is_active, :boolean, default: true)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:mcp_servers, [:name]))
    create(index(:mcp_servers, [:visibility]))
    create(index(:mcp_servers, [:owner_agent_id]))
    create(index(:mcp_servers, [:is_active]))
  end
end
