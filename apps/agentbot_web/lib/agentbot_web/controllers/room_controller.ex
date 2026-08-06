defmodule AgentbotWeb.RoomController do
  @moduledoc "Oda endpoint'leri — CRUD ve mesajlar"

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Chat.Room
  alias AgentbotCore.Modules.Chat.Message

  def index(conn, _params) do
    rooms = Room.list_active()
    json(conn, %{rooms: rooms})
  end

  def create(conn, params) do
    case Room.create(params) do
      {:ok, room} ->
        conn |> put_status(201) |> json(%{room: room})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{errors: changeset_errors(changeset)})
    end
  end

  def messages(conn, %{"id" => room_id}) do
    messages = Message.list_by_room(room_id)
    json(conn, %{messages: messages})
  end

  # HTTP POST ile mesaj gönder — LiveView fallback
  def create_message(conn, %{"room_id" => room_id, "content" => content} = params) do
    sender_name = Map.get(params, "sender_name", "İnsan")

    {:ok, _msg} = Message.create(%{
      room_id: room_id,
      sender_id: "human-web",
      sender_name: sender_name,
      content: content,
      message_type: "text"
    })

    redirect(conn, to: "/rooms/#{room_id}")
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_atom(key), key) |> to_string()
      end)
    end)
  end
end
