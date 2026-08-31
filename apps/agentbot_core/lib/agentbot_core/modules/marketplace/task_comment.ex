defmodule AgentbotCore.Modules.Marketplace.TaskComment do
  @moduledoc """
  Task Comment — kart üzerindeki takım tartışmaları ve notları.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias AgentbotCore.Repo

  schema "task_comments" do
    belongs_to(:task, AgentbotCore.Modules.Marketplace.Task)
    field(:author, :string)
    field(:body, :string)
    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:task_id, :author, :body])
    |> validate_required([:task_id, :author, :body])
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def list_by_task(task_id) do
    __MODULE__
    |> where([c], c.task_id == ^task_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  def count_by_task(task_id) do
    __MODULE__
    |> where([c], c.task_id == ^task_id)
    |> Repo.aggregate(:count)
  end
end
