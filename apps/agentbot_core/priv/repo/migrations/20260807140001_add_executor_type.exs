defmodule AgentbotCore.Repo.Migrations.AddExecutorType do
  @moduledoc """
  Agent → Executor soyutlaması.

  Agent sadece execution provider'lardan biri.
  Tool, Script, Workflow, MCP, API hepsi aynı registry'de.
  """

  use Ecto.Migration

  def change do
    alter table(:agent_credentials) do
      add :executor_type, :string, default: "agent"
      # agent | tool | script | workflow | mcp | api | container
      add :endpoint, :string
      # MCP: http://localhost:3001
      # API: https://api.example.com/webhook
      # CLI: blender
      # Workflow: n8n://workflow/183
    end

    # Executor type'a göre index — discovery hızlandır
    execute "CREATE INDEX IF NOT EXISTS agent_credentials_executor_type_idx ON agent_credentials (executor_type) WHERE is_active = true"
  end
end
