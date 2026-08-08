defmodule AgentbotCore.Modules.Council.CouncilResponse do
  @moduledoc """
  Council Response — bir agent'ın konsey sorusuna görüşü.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :council_id, :agent_id, :agent_name, :content, :stance, :confidence, :inserted_at]}
  alias AgentbotCore.Repo

  schema "council_responses" do
    belongs_to :council, AgentbotCore.Modules.Council.Council
    field :agent_id, :string
    field :agent_name, :string
    field :content, :string
    field :stance, :string          # support, oppose, neutral, alternative
    field :confidence, :decimal
    field :metadata, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(response, attrs) do
    response
    |> cast(attrs, [:council_id, :agent_id, :agent_name, :content, :stance, :confidence, :metadata])
    |> validate_required([:council_id, :agent_id, :content])
  end

  @doc "Konsey'e yanıt ver"
  def respond(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Konsey'in tüm yanıtları"
  def list_by_council(council_id) do
    __MODULE__
    |> where([r], r.council_id == ^council_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc "Bir agent bu konseye zaten yanıt vermiş mi?"
  def already_responded?(council_id, agent_id) do
    __MODULE__
    |> where([r], r.council_id == ^council_id and r.agent_id == ^agent_id)
    |> Repo.exists?()
  end

  @doc "Stance dağılımı"
  def stance_summary(council_id) do
    __MODULE__
    |> where([r], r.council_id == ^council_id)
    |> group_by([r], r.stance)
    |> select([r], {r.stance, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end
end
