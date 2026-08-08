defmodule AgentbotCore.Modules.Council.Council do
  @moduledoc """
  Council — bir soruyu birden fazla agent'a dağıt, görüşleri topla.

  Konsey: tek soru → N agent → N görüş → sentez.

  Stance tipleri:
  - support: katılıyorum
  - oppose: karşıyım
  - neutral: nötr
  - alternative: alternatif öneri
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :question, :capability, :created_by, :status, :min_responses, :synthesis, :room_id, :inserted_at, :updated_at]}
  alias AgentbotCore.Repo

  schema "councils" do
    field :question, :string
    field :capability, :string
    field :created_by, :string, default: "human"
    field :status, :string, default: "open"
    field :min_responses, :integer, default: 2
    field :synthesis, :string
    field :synthesized_by, :string
    belongs_to :room, AgentbotCore.Modules.Chat.Room
    field :deadline_at, :utc_datetime

    has_many :responses, AgentbotCore.Modules.Council.CouncilResponse

    timestamps(type: :utc_datetime)
  end

  def changeset(council, attrs) do
    council
    |> cast(attrs, [:question, :capability, :created_by, :status, :min_responses, :synthesis, :synthesized_by, :room_id, :deadline_at])
    |> validate_required([:question])
  end

  @doc "Konsey oluştur"
  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Konsey detayı + yanıtları"
  def get_with_responses!(id) do
    __MODULE__
    |> where([c], c.id == ^id)
    |> preload([:responses])
    |> Repo.one!()
  end

  @doc "Yanıt sayısı"
  def response_count(council_id) do
    AgentbotCore.Modules.Council.CouncilResponse
    |> where([r], r.council_id == ^council_id)
    |> Repo.aggregate(:count)
  end

  @doc "Durum güncelle"
  def update_status(council_id, status, opts \\ []) do
    params = %{status: status}
    params = if Keyword.has_key?(opts, :synthesis), do: Map.put(params, :synthesis, opts[:synthesis]), else: params
    params = if Keyword.has_key?(opts, :synthesized_by), do: Map.put(params, :synthesized_by, opts[:synthesized_by]), else: params

    __MODULE__
    |> Repo.get!(council_id)
    |> changeset(params)
    |> Repo.update()
  end

  @doc "Açık konseyleri listele"
  def list_open do
    __MODULE__
    |> where([c], c.status in ["open", "gathering"])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc "Son konseyleri listele"
  def list_recent(limit \\ 10) do
    __MODULE__
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
