defmodule AgentbotCore.Modules.Sync.SyncTarget do
  @moduledoc """
  SyncTarget — bir dış sistemin board/project bazında sync config'i.

  Yeni ajan/sistem eklemek kod yazmak değil, bu tabloya satır eklemektir:
  system: "github", direction: "outbound", trigger: "webhook",
  config: %{"repo" => "agentandbot-design/agentandbot_v2", "status_map" => %{...}}

  direction: "off" | "outbound" (AB → dış) | "inbound" (dış → AB) | "two_way"
  trigger:   "webhook" (gerçek zamanlı) | "poll" (periyodik)
  state:     adapter'ın pull cursor'u ve kalıcı durumu
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "sync_targets" do
    field(:system, :string)
    field(:direction, :string, default: "off")
    field(:trigger, :string, default: "webhook")
    field(:config, :map, default: %{})
    field(:enabled, :boolean, default: false)
    field(:state, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [:system, :direction, :trigger, :config, :enabled, :state])
    |> validate_required([:system, :direction])
    |> validate_inclusion(:direction, ["off", "outbound", "inbound", "two_way"])
    |> validate_inclusion(:trigger, ["webhook", "poll"])
    |> unique_constraint(:system)
  end

  @doc "Varsayılan alan haritası — dış sistemlere insan-görünümü alanları gider"
  def default_field_map do
    %{
      "title" => true,
      "summary" => true,
      "status" => true,
      "assignee" => true,
      "subtasks" => true,
      "technical_context" => false,
      "sync_metadata" => false
    }
  end

  @doc "Varsayılan status eşlemeleri"
  def default_status_map("github") do
    %{
      "open" => "open",
      "assigned" => "open",
      "in_progress" => "open",
      "review" => "review",
      "completed" => "closed",
      "failed" => "closed",
      "blocked" => "blocked"
    }
  end

  def default_status_map("hermes") do
    %{
      "open" => "todo",
      "assigned" => "ready",
      "in_progress" => "running",
      "review" => "review",
      "completed" => "done",
      "failed" => "failed",
      "blocked" => "blocked"
    }
  end

  def default_status_map(_), do: %{}
end
