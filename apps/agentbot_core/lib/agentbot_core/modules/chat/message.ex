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
