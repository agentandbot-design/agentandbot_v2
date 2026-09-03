defmodule AgentbotWeb.SkillRegistryController do
  @moduledoc """
  Skill Registry API — merkezi ajan skill yönetimi.

  Agent'lar sahip oldukları skilleri buraya kaydeder; AgentAndBot'ta
  skill bölümünde yayınlanır.

  Endpoints:
  - GET /api/skills — public skill listesi (kategori filtresi destekler)
  - GET /api/skills/:name — skill detayı (content dahil)
  - GET /api/skills/categories — kategori listesi
  - POST /api/skills/register — skill kaydet (auth, upsert)
  - POST /api/skills/:name/delete — skill deaktive et (auth)
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Registry.Skill

  @doc "Tüm public skilleri listele (auth gerekmez, kategori filtresi opsiyonel)"
  def index(conn, params) do
    category = params["category"]

    skills =
      if category && category != "" do
        Skill.list_by_category(category)
      else
        Skill.list_public()
      end

    json(conn, %{
      description: "Skill Registry — merkezi ajan skill keşfi",
      count: length(skills),
      skills: Enum.map(skills, &Skill.card_view/1),
      message: "Agent'lar sahip oldukları skilleri buradan kaydeder ve paylaşır."
    })
  end

  @doc "Kategori listesi"
  def categories(conn, _params) do
    json(conn, %{categories: Skill.list_categories()})
  end

  @doc "Skill detayı — isme göre, content dahil"
  def show(conn, %{"name" => name}) do
    agent_id = Map.get(conn.assigns, :agent_id)

    skill =
      case Skill.get_by_name(name) do
        nil -> nil
        s -> if s.is_active and (s.visibility == "public" or s.owner_agent_id == agent_id), do: s, else: nil
      end

    case skill do
      nil -> conn |> put_status(404) |> json(%{error: "Skill bulunamadı"})
      s -> json(conn, Skill.public_view(s))
    end
  end

  @doc "Yeni skill kaydet veya güncelle (auth gerekir, upsert)"
  def register(conn, params) do
    agent_id = conn.assigns.agent_id

    attrs = %{
      name: params["name"],
      description: params["description"],
      category: params["category"],
      version: params["version"],
      content: params["content"],
      tags: params["tags"],
      source: params["source"],
      visibility: params["visibility"] || "public",
      owner_agent_id: Map.get(params, "owner_agent_id", agent_id)
    }

    case Skill.register(attrs) do
      {:ok, skill} ->
        conn
        |> put_status(201)
        |> json(%{ok: true, skill: Skill.public_view(skill), message: "Skill kaydedildi"})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "Kayıt başarısız", details: inspect(changeset.errors)})
    end
  end

  @doc "Skill deaktive et (auth, sahibi olmalı)"
  def delete(conn, %{"name" => name}) do
    agent_id = conn.assigns.agent_id

    case Skill.get_by_name(name) do
      nil ->
        conn |> put_status(404) |> json(%{error: "Skill bulunamadı"})

      skill ->
        if skill.owner_agent_id == agent_id or agent_id == "admin" do
          case Skill.delete(skill) do
            {:ok, _} -> json(conn, %{ok: true, message: "Skill deaktive edildi"})
            {:error, _} -> conn |> put_status(500) |> json(%{error: "Silme başarısız"})
          end
        else
          conn |> put_status(403) |> json(%{error: "Bu skilli silme yetkiniz yok"})
        end
    end
  end
end
