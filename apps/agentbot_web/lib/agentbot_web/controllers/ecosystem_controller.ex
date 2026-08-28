defmodule AgentbotWeb.EcosystemController do
  @moduledoc """
  Ajan ekosistemi takip kataloğu API'si.

  GET /api/ecosystem — tüm katalog (kategori + öncelik sıralı)
  GET /api/ecosystem/categories — kategori listesi + istatistik
  GET /api/ecosystem?category=protocols — tek kategori
  POST /api/ecosystem — yeni giriş ekle (agent veya insan)
  """

  use AgentbotWeb, :controller

  alias AgentbotCore.Modules.Registry.EcosystemEntry

  def index(conn, params) do
    entries =
      if category = params["category"] do
        EcosystemEntry.list_by_category(category)
      else
        EcosystemEntry.list_all()
      end

    json(conn, %{
      count: length(entries),
      categories: categories_with_counts(entries),
      entries: entries
    })
  end

  def categories(conn, _params) do
    stats = EcosystemEntry.category_stats()

    categories =
      stats
      |> Enum.group_by(fn {cat, _prio, _count} -> cat end)
      |> Enum.map(fn {cat, rows} ->
        %{
          category: cat,
          total: Enum.reduce(rows, 0, fn {_c, _p, count}, acc -> acc + count end),
          priorities: Enum.map(rows, fn {_c, prio, count} -> %{priority: prio, count: count} end)
        }
      end)
      |> Enum.sort_by(& &1.category)

    json(conn, %{count: length(categories), categories: categories})
  end

  def create(conn, %{"entries" => entries}) when is_list(entries) do
    results =
      Enum.map(entries, fn entry_attrs ->
        case EcosystemEntry.upsert(entry_attrs) do
          {:ok, entry} -> %{url: entry.url, status: "ok", id: entry.id}
          {:error, changeset} -> %{url: get_field(changeset, :url), status: "error", errors: error_details(changeset)}
        end
      end)

    ok_count = Enum.count(results, &(&1.status == "ok"))
    json(conn, %{ok: ok_count, total: length(results), results: results})
  end

  def create(conn, %{"name" => _, "url" => _, "category" => _} = params) do
    attrs = %{
      name: params["name"],
      url: params["url"],
      category: params["category"],
      priority: params["priority"] || "P2",
      notes: params["notes"],
      added_by: params["added_by"] || "human"
    }

    case EcosystemEntry.upsert(attrs) do
      {:ok, entry} ->
        conn
        |> put_status(:created)
        |> json(%{ok: true, entry: entry})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{ok: false, errors: error_details(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{ok: false, error: "name, url, category gerekli (veya entries[] listesi)"})
  end

  defp categories_with_counts(entries) do
    entries
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {cat, list} -> %{category: cat, count: length(list)} end)
  end

  defp error_details(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", inspect(v)) end)
    end)
  end

  defp get_field(changeset, field), do: Ecto.Changeset.get_field(changeset, field)
end
