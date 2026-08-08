defmodule AgentbotCore.Modules.Marketplace.TaskRequirement do
  @moduledoc """
  Task gereksinimleri — bu task'ı yapmak için ne lazım.

  cpu: 4 cores, ram: 8192 MB, gpu: 1, api: openai
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :resource_type, :min_amount, :unit, :optional]}
  alias AgentbotCore.Repo

  schema "task_requirements" do
    belongs_to :task, AgentbotCore.Modules.Marketplace.Task

    field :resource_type, :string    # cpu, ram, gpu, storage, api, bandwidth
    field :min_amount, :integer
    field :unit, :string
    field :optional, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(requirement, attrs) do
    requirement
    |> cast(attrs, [:task_id, :resource_type, :min_amount, :unit, :optional])
    |> validate_required([:task_id, :resource_type, :min_amount])
  end

  @doc "Task'a gereksinim ekle"
  def add(task_id, resource_type, min_amount, unit, opts \\ []) do
    %__MODULE__{}
    |> changeset(%{
      task_id: task_id,
      resource_type: resource_type,
      min_amount: min_amount,
      unit: unit,
      optional: Keyword.get(opts, :optional, false)
    })
    |> Repo.insert()
  end

  @doc "Task'ın gereksinimlerini listele"
  def list_by_task(task_id) do
    __MODULE__
    |> where([r], r.task_id == ^task_id)
    |> Repo.all()
  end

  @doc "Zorunlu gereksinimleri getir"
  def list_required(task_id) do
    __MODULE__
    |> where([r], r.task_id == ^task_id and r.optional == false)
    |> Repo.all()
  end
end
