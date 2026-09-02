defmodule AgentbotWeb.FeedLive do
  @moduledoc """
  News Feed UI — #16

  Merkezi içerik akışı: blog, news, video, tweet, podcast, paper.
  PubSub üzerinden yeni feed item'ları real-time eklenir.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.Message
  alias AgentbotCore.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe("room:10")

    {:ok,
     socket
     |> assign(:page_title, "News Feed")
     |> assign(:type_filter, "all")
     |> assign(:tag_filter, "")
     |> assign(:site_filter, "")
     |> assign_feed()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:type_filter, Map.get(params, "type", "all"))
      |> assign(:tag_filter, Map.get(params, "tag", ""))
      |> assign(:site_filter, Map.get(params, "site", ""))
      |> assign_feed()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => t}, socket) do
    {:noreply, push_patch(socket, to: "/feed?type=#{t}")}
  end

  def handle_event("refresh", _, socket) do
    {:noreply, assign_feed(socket)}
  end

  @impl true
  def handle_info({:new_message, _msg}, socket) do
    {:noreply, assign_feed(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_feed(socket) do
    type = socket.assigns.type_filter
    tag = socket.assigns.tag_filter
    site = socket.assigns.site_filter

    opts = %{limit: 50}

    opts =
      opts
      |> maybe_put(:type, type != "all" && type)
      |> maybe_put(:tag, tag != "" && tag)
      |> maybe_put(:site, site != "" && site)

    items = Message.list_feed(opts)
    stats = Message.feed_stats()

    socket
    |> assign(:items, items)
    |> assign(:stats, stats)
  end

  defp maybe_put(map, _k, false), do: map
  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ab-content">
      <div class="ab-page-head">
        <div>
          <h1>📡 News Feed</h1>
          <p>
            Merkezi içerik akışı — blog, news, video, tweet, podcast.
            POST <code class="ab-mono">/api/feed</code> ile yeni item eklenir.
          </p>
        </div>
        <button phx-click="refresh" class="ab-btn">↻ Yenile</button>
      </div>

      <div class="ab-stats-row">
        <div class="ab-stat">
          <div class="ab-stat__num"><%= @stats.total %></div>
          <div class="ab-stat__label">toplam item</div>
        </div>
        <div class="ab-stat">
          <div class="ab-stat__num"><%= @stats.today %></div>
          <div class="ab-stat__label">bugün</div>
        </div>
        <div class="ab-stat">
          <div class="ab-stat__num"><%= map_size(@stats.by_type) %></div>
          <div class="ab-stat__label">tip çeşidi</div>
        </div>
      </div>

      <div class="ab-filters">
        <div class="ab-filter-group">
          <label class="ab-filter-label">Tip:</label>
          <%= for t <- ~w(all blog news video tweet podcast paper) do %>
            <button
              phx-click="filter_type"
              phx-value-type={t}
              class={"ab-chip #{if @type_filter == t, do: "ab-chip--active"}"}
            >
              <%= t %>
            </button>
          <% end %>
        </div>

        <%= if @stats.by_type != %{} do %>
          <div class="ab-type-summary">
            <%= for {type, count} <- Enum.sort_by(@stats.by_type, fn {_, c} -> -c end) do %>
              <span class="ab-stat-mini">
                <span class="ab-mono"><%= type %></span>: <strong><%= count %></strong>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @items == [] do %>
        <div class="ab-empty">
          Henüz feed yok —
          <code class="ab-mono">POST /api/feed</code> ile başla:
          <pre class="ab-code">curl -X POST http://localhost:4000/api/feed -H 'Content-Type: application/json' -d 'curl-body'</pre>
        </div>
      <% else %>
        <div class="ab-feed-grid">
          <%= for item <- @items do %>
            <% meta = item.metadata || %{} %>
            <article class="ab-feed-card">
              <header class="ab-feed-card__head">
                <span class={"ab-type-badge ab-type-badge--#{meta["type"] || "news"}"}>
                  <%= meta["type"] || "news" %>
                </span>
                <%= for s <- (meta["sites"] || []) |> Enum.take(2) do %>
                  <span class="ab-site-tag"><%= s %></span>
                <% end %>
                <time class="ab-feed-card__time">
                  <%= format_time(item.inserted_at) %>
                </time>
              </header>

              <h3 class="ab-feed-card__title">
                <%= meta["title"] || String.slice(item.content || "", 0, 80) %>
              </h3>

              <p class="ab-feed-card__excerpt">
                <%= meta["excerpt"] || String.slice(item.content || "", 0, 160) %>
              </p>

              <%= if meta["source_url"] && meta["source_url"] != "" do %>
                <a href={meta["source_url"]} target="_blank" class="ab-feed-card__source">
                  Kaynak ↗
                </a>
              <% end %>

              <%= if (meta["tags"] || []) != [] do %>
                <div class="ab-feed-card__tags">
                  <%= for tag <- Enum.take(meta["tags"] || [], 5) do %>
                    <span class="ab-tag-chip">#<%= tag %></span>
                  <% end %>
                </div>
              <% end %>

              <footer class="ab-feed-card__foot">
                <span class="ab-feed-card__author"><%= item.sender_name %></span>
                <span class="ab-feed-card__id">#<%= item.id %></span>
              </footer>
            </article>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_time(dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 ->
        "şimdi"

      diff < 3600 ->
        "#{div(diff, 60)}dk"

      diff < 86_400 ->
        "#{div(diff, 3600)}sa"

      diff < 604_800 ->
        "#{div(diff, 86_400)}g"

      true ->
        {{y, m, d}, {h, mm, _}} = dt |> DateTime.to_date() |> then(&{&1, {0, 0, 0}})
        "#{y}-#{pad(m)}-#{pad(d)} #{pad(h)}:#{pad(mm)}"
    end
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end
