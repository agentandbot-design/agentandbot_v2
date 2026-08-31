defmodule AgentbotCore.Modules.Marketplace.TaskEvent do
  @moduledoc """
  Task Event — tüm değişikliklerin zaman tüyü (audit trail).
  Oluşturma, durum değişikliği, atama, yorum, etiket ekleme, arşivleme.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias AgentbotCore.Repo

  schema "task_events" do
    belongs_to(:task, AgentbotCore.Modules.Marketplace.Task)
    field(:actor, :string)
    field(:action, :string)
    field(:details, :map, default: %{})
    field(:inserted_at, :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:task_id, :actor, :action, :details, :inserted_at])
    |> validate_required([:task_id, :actor, :action])
  end

  @doc "Yeni event kaydet"
  def log(task_id, actor, action, details \\ %{}) do
    %__MODULE__{}
    |> changeset(%{
      task_id: task_id,
      actor: actor,
      action: action,
      details: details,
      inserted_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc "Bir task'ın tüm eventlerini zaman tüyü olarak listele"
  def list_by_task(task_id) do
    __MODULE__
    |> where([e], e.task_id == ^task_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit([e], 50)
    |> Repo.all()
  end

  @doc "Son N eventi getir (global timeline)"
  def list_recent(limit \\ 20) do
    __MODULE__
    |> order_by([e], desc: e.inserted_at)
    |> limit([e], ^limit)
    |> Repo.all()
  end
end
