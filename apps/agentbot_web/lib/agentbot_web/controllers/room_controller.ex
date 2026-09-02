defmodule AgentbotWeb.RoomController do
  @moduledoc "Oda endpoint'leri — CRUD ve mesajlar"

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Chat.Message
  alias AgentbotCore.Modules.Chat.Room

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

  @doc "Belirli ID'den sonraki mesajları döndürür (agent polling)"
  def messages_since(conn, %{"id" => room_id, "last_id" => last_id}) do
    messages = Message.list_since(room_id, last_id)
    json(conn, %{messages: messages, count: length(messages)})
  end

  # HTTP POST ile mesaj gönder — LiveView fallback
  def create_message(conn, %{"room_id" => room_id} = params) do
    # JSON body parse
    body = if conn.body_params == %{}, do: params, else: Map.merge(params, conn.body_params)
    content = Map.get(body, "content") || Map.get(params, "content", "")
    sender_name = Map.get(body, "sender_name", Map.get(params, "sender_name", "İnsan"))
    metadata = Map.get(body, "metadata", Map.get(params, "metadata", %{}))

    {:ok, _msg} =
      Message.create(%{
        room_id: room_id,
        sender_id: "human-web",
        sender_name: sender_name,
        content: content,
        message_type: "text",
        metadata: metadata
      })

    json(conn, %{status: "ok", message: "Mesaj oluşturuldu"})
  end

  # Feed API — site filtresiyle mesajları döndürür
  def feed(conn, params) do
    {limit, _} = Integer.parse(Map.get(params, "limit", "20"))

    opts =
      %{}
      |> Map.put(:limit, limit)
      |> maybe_put(:site, Map.get(params, "site"))
      |> maybe_put(:type, Map.get(params, "type"))
      |> maybe_put(:tag, Map.get(params, "tag"))
      |> maybe_put_int(:since_id, Map.get(params, "since_id"))
      |> maybe_put_at(:since_at, Map.get(params, "since"))
      |> maybe_put_sites(Map.get(params, "sites"))

    messages = Message.list_feed(opts)
    json(conn, %{feed: messages, count: length(messages)})
  end

  @doc "POST /api/feed — dışarıdan feed item ekler (public)"
  def create_feed(conn, params) do
    body =
      if conn.body_params == %{},
        do: params,
        else: Map.merge(params, conn.body_params)

    title = Map.get(body, "title", "")
    content = Map.get(body, "content", "")
    excerpt = Map.get(body, "excerpt", "")

    cond do
      title == "" or not is_binary(title) ->
        conn |> put_status(400) |> json(%{error: "title zorunlu"})

      content == "" and excerpt == "" ->
        conn |> put_status(400) |> json(%{error: "content veya excerpt zorunlu"})

      true ->
        type = Map.get(body, "type", "news")
        valid_types = ~w(blog news video tweet podcast paper)

        if type not in valid_types do
          conn |> put_status(422) |> json(%{error: "type geçersiz: #{type}", valid: valid_types})
        else
          attrs = %{
            title: title,
            content: content,
            excerpt: excerpt,
            type: type,
            source_url: Map.get(body, "source_url", ""),
            tags: parse_list(Map.get(body, "tags", [])),
            sites: parse_list(Map.get(body, "sites", ["agentandbot"])),
            canonical_site: Map.get(body, "canonical_site", "agentandbot"),
            sender_id: Map.get(body, "sender_id", "external-feed"),
            sender_name: Map.get(body, "sender_name", "Feed Bot"),
            published_at: parse_datetime(Map.get(body, "published_at"))
          }

          case Message.create_feed_item(attrs) do
            {:ok, msg} ->
              conn
              |> put_status(201)
              |> json(%{
                status: "ok",
                id: msg.id,
                manifest_url: "/api/feed/#{msg.id}",
                metadata: msg.metadata
              })

            {:error, _} ->
              conn |> put_status(422) |> json(%{error: "Feed kaydedilemedi"})
          end
        end
    end
  end

  @doc "POST /api/feed/stats — feed istatistikleri (tip dağılımı)"
  def feed_stats(conn, _params) do
    json(conn, Message.feed_stats())
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == "", do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_int(map, _key, nil), do: map
  defp maybe_put_int(map, _key, ""), do: map

  defp maybe_put_int(map, key, value) do
    case Integer.parse(value) do
      {n, _} -> Map.put(map, key, n)
      :error -> map
    end
  end

  defp maybe_put_at(map, _key, nil), do: map
  defp maybe_put_at(map, _key, ""), do: map

  defp maybe_put_at(map, key, value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> Map.put(map, key, dt)
      _ -> map
    end
  end

  defp maybe_put_sites(map, nil), do: map
  defp maybe_put_sites(map, ""), do: map

  defp maybe_put_sites(map, value) do
    sites =
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if sites == [], do: map, else: Map.put(map, :sites, sites)
  end

  defp parse_list(nil), do: []
  defp parse_list([]), do: []
  defp parse_list(value) when is_list(value), do: value

  defp parse_list(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(value), do: value

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_atom(key), key) |> to_string()
      end)
    end)
  end
end
