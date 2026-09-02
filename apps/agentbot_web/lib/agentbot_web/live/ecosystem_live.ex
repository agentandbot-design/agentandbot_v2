defmodule AgentbotWeb.EcosystemLive do
  @moduledoc """
  Ajan ekosistemi takip kataloğu sayfası.

  AgentAndBot'un izlediği standartlar, protokoller, framework'ler.
  İnsanlar ve agent'lar kategori bazlı giriş ekler.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Registry.EcosystemEntry
  alias AgentbotCore.Repo

  @categories [
    {"protocols", "Protokoller ve İletişim"},
    {"skills", "Skills"},
    {"standards", "API / Interface / Identity Standartları"},
    {"providers", "Tool ve Model API Sağlayıcıları"},
    {"ui", "UI / Human-in-the-Loop / Browser"},
    {"observability", "Gözlemlenebilirlik ve Trace"},
    {"evaluation", "Değerlendirme ve Benchmark"},
    {"security", "Güvenlik ve Yönetişim"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    entries = EcosystemEntry.list_all()

    {:ok,
     socket
     |> assign(:categories, @categories)
     |> assign(:entries, entries)
     |> assign(:stats, compute_stats(entries))
     |> assign(:message, nil)}
  end

  @impl true
  def handle_event("add_entry", %{"entry" => entry_params}, socket) do
    attrs = normalize_entry(entry_params)

    case EcosystemEntry.upsert(attrs) do
      {:ok, entry} ->
        entries = EcosystemEntry.list_all()

        {:noreply,
         socket
         |> assign(:message, %{type: "success", text: "Eklendi: #{entry.name}"})
         |> assign(:entries, entries)
         |> assign(:stats, compute_stats(entries))}

      {:error, changeset} ->
        {:noreply, assign(socket, :message, %{type: "error", text: format_errors(changeset)})}
    end
  end

  def handle_event("check", %{"id" => id}, socket) do
    entry = Repo.get(EcosystemEntry, String.to_integer(id))

    case entry &&
           Repo.update(
             EcosystemEntry.changeset(entry, %{
               status: "checked",
               last_checked_at: DateTime.utc_now()
             })
           ) do
      {:ok, _} ->
        {:noreply, assign(socket, :entries, EcosystemEntry.list_all())}

      _ ->
        {:noreply, assign(socket, :message, %{type: "error", text: "Güncellenemedi: #{id}"})}
    end
  end

  defp normalize_entry(params) do
    %{
      name: params["name"],
      url: params["url"],
      category: params["category"],
      priority: params["priority"] || "P2",
      notes: params["notes"],
      added_by: "human"
    }
  end

  defp compute_stats(entries) do
    %{
      total: length(entries),
      p0: Enum.count(entries, &(&1.priority == "P0")),
      p1: Enum.count(entries, &(&1.priority == "P1")),
      p2: Enum.count(entries, &(&1.priority == "P2")),
      categories: entries |> Enum.map(& &1.category) |> Enum.uniq() |> length
    }
  end

  defp format_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", inspect(v)) end)
      end)

    inspect(errors)
  end
end
