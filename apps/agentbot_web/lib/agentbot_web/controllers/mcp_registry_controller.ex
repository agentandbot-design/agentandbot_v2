defmodule AgentbotWeb.McpRegistryController do
  @moduledoc """
  MCP Registry API — merkezi MCP sunucu yönetimi.

  Public MCP'leri her agent keşfedebilir.
  Private MCP'leri sadece sahibi görebilir ve yönetebilir.

  Endpoints:
  - GET /api/mcp-servers — public MCP listesi
  - GET /api/mcp-servers/:name — MCP detayı
  - GET /api/mcp-servers/search/:tag — etikete göre ara
  - POST /api/mcp-servers/register — MCP kaydet (auth)
  - PUT /api/mcp-servers/:name — MCP güncelle (auth)
  - DELETE /api/mcp-servers/:name — MCP sil/deaktive et (auth)
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Registry.McpServer

  @doc "Tüm public MCP sunucularını listele (auth gerekmez)"
  def index(conn, _params) do
    servers = McpServer.list_public()

    json(conn, %{
      description: "MCP Registry — merkezi MCP sunucu keşfi",
      count: length(servers),
      servers: Enum.map(servers, &public_view/1),
      message: "Public MCP'leri her agent kullanabilir. Private MCP'ler icin auth gerekir."
    })
  end

  @doc "MCP sunucu detayı — isme göre (public olanı herkes görebilir)"
  def show(conn, %{"name" => name}) do
    agent_id = Map.get(conn.assigns, :agent_id)

    server =
      if agent_id do
        McpServer.get_by_name_for_agent(name, agent_id)
      else
        case McpServer.get_by_name(name) do
          nil -> nil
          s -> if s.visibility == "public" and s.is_active, do: s, else: nil
        end
      end

    case server do
      nil -> conn |> put_status(404) |> json(%{error: "MCP sunucu bulunamadı"})
      s -> json(conn, format_detail(s))
    end
  end

  @doc "Etikete göre MCP ara"
  def search(conn, %{"tag" => tag}) do
    servers = McpServer.search_by_tag(tag)

    json(conn, %{
      tag: tag,
      count: length(servers),
      servers: Enum.map(servers, &public_view/1)
    })
  end

  @doc "Yeni MCP sunucu kaydet (auth gerekir)"
  def register(conn, params) do
    agent_id = conn.assigns.agent_id

    attrs = %{
      name: params["name"],
      description: params["description"],
      transport_type: params["transport_type"] || "http",
      url: params["url"],
      command: params["command"],
      args: params["args"],
      headers: params["headers"],
      visibility: params["visibility"] || "public",
      tags: params["tags"],
      owner_agent_id: if(params["visibility"] == "private", do: agent_id, else: nil),
      is_active: true
    }

    case McpServer.register(attrs) do
      {:ok, server} ->
        conn
        |> put_status(201)
        |> json(%{
          status: "registered",
          name: server.name,
          visibility: server.visibility,
          message:
            "MCP sunucu '#{server.name}' kaydedildi. #{if server.visibility == "public", do: "Tum agent'lar kullanabilir.", else: "Sadece sen gorebilirsin."}"
        })

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
        conn |> put_status(422) |> json(%{errors: errors})
    end
  end

  @doc "MCP sunucu güncelle (auth gerekir — sadece sahibi veya public olanı her agent güncelleyebilir)"
  def update(conn, %{"name" => name} = params) do
    agent_id = conn.assigns.agent_id

    server = McpServer.get_by_name_for_agent(name, agent_id)

    case server do
      nil ->
        conn |> put_status(404) |> json(%{error: "MCP sunucu bulunamadı veya yetkiniz yok"})

      s ->
        attrs = %{}

        attrs =
          if params["description"],
            do: Map.put(attrs, :description, params["description"]),
            else: attrs

        attrs = if params["url"], do: Map.put(attrs, :url, params["url"]), else: attrs
        attrs = if params["command"], do: Map.put(attrs, :command, params["command"]), else: attrs
        attrs = if params["args"], do: Map.put(attrs, :args, params["args"]), else: attrs
        attrs = if params["headers"], do: Map.put(attrs, :headers, params["headers"]), else: attrs
        attrs = if params["tags"], do: Map.put(attrs, :tags, params["tags"]), else: attrs

        case McpServer.update(s, attrs) do
          {:ok, updated} ->
            json(conn, %{status: "updated", name: updated.name})

          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
            conn |> put_status(422) |> json(%{errors: errors})
        end
    end
  end

  @doc "MCP sunucuyu sil/deaktive et (auth gerekir — sadece sahibi)"
  def delete(conn, %{"name" => name}) do
    agent_id = conn.assigns.agent_id

    server = McpServer.get_by_name(name)

    case server do
      nil ->
        conn |> put_status(404) |> json(%{error: "MCP sunucu bulunamadı"})

      s when s.visibility == "private" and s.owner_agent_id != agent_id ->
        conn |> put_status(403) |> json(%{error: "Bu MCP sunucuyu silme yetkiniz yok"})

      s ->
        {:ok, _} = McpServer.deactivate(s)
        json(conn, %{status: "deactivated", name: s.name})
    end
  end

  # ── Private yardımcılar ──

  defp public_view(server) do
    %{
      name: server.name,
      description: server.description,
      transport_type: server.transport_type,
      tags: server.tags,
      visibility: server.visibility
    }
  end

  defp format_detail(server) do
    base = %{
      name: server.name,
      description: server.description,
      transport_type: server.transport_type,
      url: server.url,
      command: server.command,
      args: server.args,
      tags: server.tags,
      visibility: server.visibility,
      is_active: server.is_active,
      registered_at: server.inserted_at
    }

    # headers sadece private MCP sahibine gösterilir
    base
  end
end
