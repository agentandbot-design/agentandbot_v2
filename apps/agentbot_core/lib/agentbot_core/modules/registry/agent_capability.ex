defmodule AgentbotCore.Modules.Registry.AgentCapability do
  @moduledoc """
  Agent ↔ Capability junction — provider relationship.

  Bir agent'ın bir capability'yi sağladığı ilişki.
  Evidence-based: tasks_completed, success_rate.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :agent_credential_id, :capability_id, :verified, :tasks_completed, :tasks_failed, :success_rate]}
  alias AgentbotCore.Repo

  schema "agent_capabilities" do
    belongs_to :agent_credential, AgentbotCore.Modules.Security.AgentCredential
    belongs_to :capability, AgentbotCore.Modules.Registry.Capability

    field :verified, :boolean, default: false
    field :tasks_completed, :integer, default: 0
    field :tasks_failed, :integer, default: 0
    field :success_rate, :decimal

    timestamps(type: :utc_datetime)
  end

  def changeset(agent_capability, attrs) do
    agent_capability
    |> cast(attrs, [:agent_credential_id, :capability_id, :verified, :tasks_completed, :tasks_failed, :success_rate])
    |> validate_required([:agent_credential_id, :capability_id])
    |> unique_constraint([:agent_credential_id, :capability_id])
  end

  @doc "Agent'a capability sağla (register as provider)"
  def provide(agent_credential_id, capability_id) do
    case Repo.get_by(__MODULE__, agent_credential_id: agent_credential_id, capability_id: capability_id) do
      nil ->
        %__MODULE__{}
        |> changeset(%{agent_credential_id: agent_credential_id, capability_id: capability_id})
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc "Task tamamlandı — istatistik güncelle"
  def record_completion(agent_credential_id, capability_id, success) do
    entry = Repo.get_by(__MODULE__, agent_credential_id: agent_credential_id, capability_id: capability_id)

    if entry do
      {completed, failed} =
        if success do
          {entry.tasks_completed + 1, entry.tasks_failed}
        else
          {entry.tasks_completed, entry.tasks_failed + 1}
        end

      total = completed + failed
      rate = if total > 0, do: Decimal.div(Decimal.new(completed), Decimal.new(total)), else: Decimal.new("0")

      entry
      |> changeset(%{tasks_completed: completed, tasks_failed: failed, success_rate: rate})
      |> Repo.update()
    else
      {:error, :not_found}
    end
  end

  @doc "Bir agent'ın tüm capability'lerini listele"
  def list_by_agent(agent_credential_id) do
    __MODULE__
    |> where([ac], ac.agent_credential_id == ^agent_credential_id)
    |> preload([:capability])
    |> Repo.all()
  end
end
