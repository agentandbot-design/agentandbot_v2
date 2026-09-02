defmodule AgentbotCore.Modules.ActivityLog do
  @moduledoc """
  SAP Danışmanlık Günlüğü — günlük aktivite takibi.
  Google Docs ile senkronize olur.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias AgentbotCore.Repo

  @statuses ["draft", "in_progress", "done", "archived"]
  @categories ["sap", "infra", "meeting", "note", "idea"]

  schema "activity_logs" do
    field(:date, :date, default: Date.utc_today())
    field(:title, :string)
    field(:content, :string, default: "")
    field(:tags, :string)
    field(:status, :string, default: "draft")
    field(:category, :string, default: "sap")
    field(:google_doc_id, :string)
    field(:google_doc_url, :string)
    field(:synced_at, :utc_datetime)
    field(:created_by, :string, default: "ilkerkaan")

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, [
      :date,
      :title,
      :content,
      :tags,
      :status,
      :category,
      :google_doc_id,
      :google_doc_url,
      :synced_at,
      :created_by
    ])
    |> validate_required([:date, :title])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:category, @categories)
  end

  @doc "Günlük aktivite listele"
  def list_by_date(date) do
    Repo.all(
      from(a in __MODULE__,
        where: a.date == ^date,
        order_by: [desc: a.inserted_at]
      )
    )
  end

  @doc "Tüm aktiviteleri listele (tarihe göre)"
  def list_all(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    Repo.all(
      from(a in __MODULE__,
        order_by: [desc: a.date, desc: a.inserted_at],
        limit: ^limit
      )
    )
  end

  @doc "Yeni aktivite oluştur"
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Aktivite güncelle"
  def update(%__MODULE__{} = activity_log, attrs) do
    activity_log
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "Aktivite sil"
  def delete(%__MODULE__{} = activity_log) do
    Repo.delete(activity_log)
  end

  @doc "Tek aktivite getir"
  def get!(id), do: Repo.get!(AgentbotCore.Modules.ActivityLog, id)

  @doc "Statü güncelle"
  def update_status(id, status) when status in @statuses do
    get!(id)
    |> Ecto.Changeset.change(status: status)
    |> Repo.update()
  end

  @doc "Google Docs'a senkronize et"
  def sync_to_google(%__MODULE__{} = activity_log) do
    case AgentbotCore.Modules.GoogleDocs.sync_activity(activity_log) do
      {:ok, doc_id, doc_url} ->
        activity_log
        |> Ecto.Changeset.change(%{
          google_doc_id: doc_id,
          google_doc_url: doc_url,
          synced_at: DateTime.utc_now()
        })
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Kategorileri döndür"
  def categories, do: @categories

  @doc "Statüleri döndür"
  def statuses, do: @statuses
end
