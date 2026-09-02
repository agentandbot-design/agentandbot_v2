defmodule AgentbotCore.Modules.Chat.Message do
  @moduledoc """
  Mesaj — odadaki bir iletişim birimi.

  Ecto schema ile veritabanında saklanır.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :id,
             :room_id,
             :sender_id,
             :sender_name,
             :content,
             :message_type,
             :event_type,
             :metadata,
             :inserted_at,
             :updated_at
           ]}
  alias AgentbotCore.Repo

  schema "messages" do
    belongs_to(:room, AgentbotCore.Modules.Chat.Room)
    field(:sender_id, :string)
    field(:sender_name, :string)
    field(:content, :string)
    # text, system, command
    field(:message_type, :string, default: "text")
    field(:event_type, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  @doc "Yeni mesaj oluşturmak için changeset"
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :room_id,
      :sender_id,
      :sender_name,
      :content,
      :message_type,
      :event_type,
      :metadata
    ])
    |> validate_required([:room_id, :sender_id, :content])
  end

  @doc "Odadaki mesajları listeler (son mesajlar önce)"
  def list_by_room(room_id, limit \\ 50) do
    __MODULE__
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Feed mesajlarını geniş filtrelerle listele (site, type, tag, since, sites, limit)"
  def list_feed(opts \\ %{}) do
    limit = Map.get(opts, :limit, 20)
    since_id = Map.get(opts, :since_id)
    since_at = Map.get(opts, :since_at)
    site = Map.get(opts, :site)
    type = Map.get(opts, :type)
    tag = Map.get(opts, :tag)
    sites = Map.get(opts, :sites)

    query =
      __MODULE__
      |> where([m], m.room_id == 10)
      |> order_by([m], desc: m.inserted_at)
      |> limit(^limit)

    query =
      if since_id,
        do: from(m in query, where: m.id > ^since_id),
        else: query

    query =
      if since_at,
        do: from(m in query, where: m.inserted_at > ^since_at),
        else: query

    query =
      if site,
        do: from(m in query, where: fragment("?->>'sites' LIKE ?", m.metadata, ^"%#{site}%")),
        else: query

    query =
      if is_list(sites) and sites != [],
        do:
          from(m in query,
            where: fragment("?->>'sites' \\? ?", m.metadata, ^Enum.at(sites, 0))
          ),
        else: query

    query =
      if type,
        do: from(m in query, where: fragment("?->>'type' = ?", m.metadata, ^type)),
        else: query

    query =
      if tag,
        do: from(m in query, where: fragment("?->>'tags' LIKE ?", m.metadata, ^"%\"#{tag}\"%")),
        else: query

    Repo.all(query)
  end

  @doc "Feed istatistikleri — tip dağılımı ve toplam"
  def feed_stats do
    items = Repo.all(from(m in __MODULE__, where: m.room_id == 10))

    types =
      items
      |> Enum.frequencies_by(fn m -> get_in(m.metadata, ["type"]) || "other" end)

    today_count =
      today = Date.utc_today()

    Enum.count(items, fn m -> DateTime.to_date(m.inserted_at) == today end)

    %{
      total: length(items),
      today: today_count,
      by_type: types
    }
  end

  @doc "Feed item oluştur — özel şema ile"
  def create_feed_item(attrs) do
    metadata =
      %{}
      |> Map.put("title", Map.get(attrs, :title, ""))
      |> Map.put("excerpt", Map.get(attrs, :excerpt, ""))
      |> Map.put("type", Map.get(attrs, :type, "news"))
      |> Map.put("source_url", Map.get(attrs, :source_url, ""))
      |> Map.put("tags", Map.get(attrs, :tags, []))
      |> Map.put("sites", Map.get(attrs, :sites, []))
      |> Map.put("canonical_site", Map.get(attrs, :canonical_site, "agentandbot"))
      |> Map.put("published_at", Map.get(attrs, :published_at))

    create(%{
      room_id: 10,
      sender_id: Map.get(attrs, :sender_id, "external-feed"),
      sender_name: Map.get(attrs, :sender_name, "Feed Bot"),
      content:
        Map.get(attrs, :content, "") <>
          if(Map.get(attrs, :excerpt), do: "\n\n" <> Map.get(attrs, :excerpt), else: ""),
      message_type: "feed",
      metadata: metadata
    })
  end

  @doc "Belirli ID'den sonraki mesajları listeler (agent polling)"
  def list_since(room_id, last_id) do
    __MODULE__
    |> where([m], m.room_id == ^room_id and m.id > ^last_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc "Mesaj oluşturur ve PubSub'a yayınlar"
  def create(attrs) do
    changeset = changeset(%__MODULE__{}, attrs)

    with {:ok, message} <- Repo.insert(changeset) do
      # PubSub'a yayınla
      AgentbotCore.PubSub.broadcast(
        "room:#{attrs.room_id}",
        "new_message",
        message
      )

      {:ok, message}
    end
  end
end
