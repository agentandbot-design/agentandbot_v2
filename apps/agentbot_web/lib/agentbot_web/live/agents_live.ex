defmodule AgentbotWeb.AgentsLive do
  @moduledoc """
  Agent Manifest Registry — #23

  Kayıtlı agent'ları, executor_type'larına göre gruplanmış manifest kartları halinde gösterir.
  Detay modalı açılır, JSON pretty-print + kopyala.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Agents.AgentPresence
  alias AgentbotCore.Modules.Security.AgentCredential

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Agent Manifest Registry")
     |> assign(:selected, nil)
     |> assign(:filter_type, "all")
     |> assign_agents()}
  end

  @impl true
  def handle_event("open_manifest", %{"agent_id" => id}, socket) do
    {:noreply, assign(socket, :selected, id)}
  end

  def handle_event("close_manifest", _, socket) do
    {:noreply, assign(socket, :selected, nil)}
  end

  def handle_event("filter_type", %{"type" => t}, socket) do
    {:noreply, assign(socket, :filter_type, t)}
  end

  defp assign_agents(socket) do
    manifests = AgentCredential.list_active_manifests()
    online = AgentPresence.list_online() |> Enum.map(& &1.agent_id) |> MapSet.new()

    by_type =
      manifests
      |> Enum.frequencies_by(& &1.executor_type)
      |> Enum.sort_by(fn {_, c} -> -c end)

    socket
    |> assign(:manifests, manifests)
    |> assign(:online, online)
    |> assign(:by_type, by_type)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ab-content">
      <div class="ab-page-head">
        <div>
          <h1>🤖 Agent Manifest Registry</h1>
          <p>
            Kayıtlı tüm agent'ların manifest'i —
            <code class="ab-mono">GET /api/agents</code> · tekil:
            <code class="ab-mono">/api/agents/:agent_id/manifest</code>
          </p>
        </div>
      </div>

      <div class="ab-stats-row">
        <div class="ab-stat">
          <div class="ab-stat__num"><%= length(@manifests) %></div>
          <div class="ab-stat__label">kayıtlı agent</div>
        </div>
        <div class="ab-stat">
          <div class="ab-stat__num"><%= MapSet.size(@online) %></div>
          <div class="ab-stat__label">online şu an</div>
        </div>
        <div class="ab-stat">
          <div class="ab-stat__num"><%= map_size(Enum.into(@by_type, %{})) %></div>
          <div class="ab-stat__label">executor tipi</div>
        </div>
      </div>

      <%= if @by_type != [] do %>
        <div class="ab-filters">
          <div class="ab-filter-group">
            <label class="ab-filter-label">Executor tipi:</label>
            <button
              phx-click="filter_type"
              phx-value-type="all"
              class={"ab-chip #{if @filter_type == "all", do: "ab-chip--active"}"}
            >
              tümü (<%= length(@manifests) %>)
            </button>
            <%= for {type, count} <- @by_type do %>
              <button
                phx-click="filter_type"
                phx-value-type={type}
                class={"ab-chip #{if @filter_type == type, do: "ab-chip--active"}"}
              >
                <%= type %> (<%= count %>)
              </button>
            <% end %>
          </div>
        </div>
      <% end %>

      <% filtered = filter_manifests(@manifests, @filter_type) %>

      <%= if filtered == [] do %>
        <div class="ab-empty">Bu filtreye uyan agent yok.</div>
      <% else %>
        <div class="ab-agent-grid">
          <%= for m <- filtered do %>
            <% online_class = if MapSet.member?(@online, m.agent_id), do: "ab-agent-card ab-agent-card--online", else: "ab-agent-card" %>
            <% exec_class = "ab-executor-badge ab-executor-badge--" <> m.executor_type %>
            <article class={online_class}>
              <header class="ab-agent-card__head">
                <div class="ab-agent-card__id">
                  <h3><%= m.agent_name %></h3>
                  <code class="ab-mono"><%= m.agent_id %></code>
                </div>
                <span class="ab-agent-card__badges">
                  <span class={"ab-char " <> if(m.executor_type == "agent", do: "ab-char--agent", else: "ab-char--bot")}>
                    <span class="ab-char__dot"><%= if m.executor_type == "agent", do: "🤖", else: "🔧" %></span>
                    <%= if m.executor_type == "agent", do: "agent", else: "bot/tool" %>
                  </span>
                  <span class={exec_class}>
                    <%= m.executor_type %>
                  </span>
                </span>
              </header>

              <%= if m.description do %>
                <p class="ab-agent-card__desc"><%= m.description %></p>
              <% end %>

              <div class="ab-agent-card__caps">
                <%= for cap <- Enum.take(m.capabilities, 6) do %>
                  <span class="ab-cap-chip"><%= cap %></span>
                <% end %>
                <%= if length(m.capabilities) > 6 do %>
                  <span class="ab-cap-chip ab-cap-chip--more">+<%= length(m.capabilities) - 6 %></span>
                <% end %>
              </div>

              <%= if m.endpoint do %>
                <div class="ab-agent-card__endpoint">
                  <code class="ab-mono"><%= m.endpoint %></code>
                </div>
              <% end %>

              <footer class="ab-agent-card__foot">
                <span class="ab-agent-card__meta">
                  <%= for p <- m.protocols do %>
                    <span class="ab-proto-tag"><%= p %></span>
                  <% end %>
                  · v<%= m.version %>
                </span>
                <button
                  phx-click="open_manifest"
                  phx-value-agent_id={m.agent_id}
                  class="ab-btn ab-btn--small"
                >
                  manifest.json
                </button>
              </footer>

              <%= if MapSet.member?(@online, m.agent_id) do %>
                <span class="ab-online-dot" title="online">●</span>
              <% end %>
            </article>
          <% end %>
        </div>
      <% end %>

      <%= if @selected do %>
        <.live_component module={AgentbotWeb.AgentManifestModal} id="agent-manifest-modal" agent_id={@selected}>
        </.live_component>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_info(:close_manifest, socket) do
    {:noreply, assign(socket, :selected, nil)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp filter_manifests(manifests, "all"), do: manifests

  defp filter_manifests(manifests, type) do
    Enum.filter(manifests, &(&1.executor_type == type))
  end
end
