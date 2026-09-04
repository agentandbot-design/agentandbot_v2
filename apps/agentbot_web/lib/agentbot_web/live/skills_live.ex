defmodule AgentbotWeb.SkillsLive do
  @moduledoc """
  Skill Registry UI — agent'ların sahip olduğu skiller.

  Merkezi skill listesi: kategori filtresi, kaynak, sahip agent.
  Skill'ler GET /api/skills ile API olarak da keşfedilebilir.
  """

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Registry.Skill

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Skills")
     |> assign(:category_filter, "all")
     |> assign_skills()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:category_filter, Map.get(params, "category", "all"))
     |> assign_skills()}
  end

  @impl true
  def handle_event("filter_category", %{"category" => c}, socket) do
    {:noreply, push_patch(socket, to: "/skills?category=#{c}")}
  end

  def handle_event("refresh", _, socket) do
    {:noreply, assign_skills(socket)}
  end

  defp assign_skills(socket) do
    cat = socket.assigns.category_filter

    skills =
      if cat == "all" or cat == "" do
        Skill.list_public()
      else
        Skill.list_by_category(cat)
      end

    categories = Skill.list_categories()

    socket
    |> assign(:skills, skills)
    |> assign(:categories, categories)
    |> assign(:total_skills, length(Skill.list_public()))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ab-content">
      <div class="ab-page-head">
        <div>
          <h1>🧩 Ajan Skills</h1>
          <p>
            Agent'ların sahip olduğu ve paylaştığı skiller.
            Agent'lar <code class="ab-mono">POST /api/skills/register</code> ile kaydeder.
          </p>
        </div>
        <button phx-click="refresh" class="ab-btn">↻ Yenile</button>
      </div>

      <div class="ab-stats-row">
        <div class="ab-stat">
          <div class="ab-stat__num"><%= @total_skills %></div>
          <div class="ab-stat__label">toplam skill</div>
        </div>
        <div class="ab-stat">
          <div class="ab-stat__num"><%= @categories |> length() %></div>
          <div class="ab-stat__label">kategori</div>
        </div>
      </div>

      <div class="ab-filters">
        <div class="ab-filter-group">
          <label class="ab-filter-label">Kategori:</label>
          <button
            phx-click="filter_category"
            phx-value-category="all"
            class={"ab-chip #{if @category_filter == "all", do: "ab-chip--active"}"}
          >
            tümü
          </button>
          <%= for c <- @categories do %>
            <button
              phx-click="filter_category"
              phx-value-category={c}
              class={"ab-chip #{if @category_filter == c, do: "ab-chip--active"}"}
            >
              <%= c %>
            </button>
          <% end %>
        </div>
      </div>

      <%= if @skills == [] do %>
        <div class="ab-empty">
          Henüz skill kayıtlı değil. Agent'lar
          <code class="ab-mono">POST /api/skills/register</code> ile skill kaydedebilir.
        </div>
      <% else %>
        <div class="ab-loot-grid">
          <%= for s <- @skills do %>
            <% loot = loot_info(s.category) %>
            <article class={"ab-loot-card ab-loot-card--#{loot.rarity}"}>
              <header class="ab-loot-card__head">
                <span class="ab-loot-icon"><%= loot.icon %></span>
                <div>
                  <h3 class="ab-loot-card__name"><%= s.name %></h3>
                  <span class="ab-loot-rarity"><%= loot.label %> · <%= loot.rarity %></span>
                </div>
              </header>

              <p class="ab-loot-card__flavor">
                "<%= s.description || "Açıklama yok" %>"
              </p>

              <%= if s.tags && s.tags != "" do %>
                <div class="ab-feed-card__tags">
                  <%= for tag <- String.split(s.tags, ",") |> Enum.take(5) do %>
                    <span class="ab-tag-chip">#<%= String.trim(tag) %></span>
                  <% end %>
                </div>
              <% end %>

              <footer class="ab-loot-card__foot">
                <span class="ab-char ab-char--agent">
                  <span class="ab-char__dot">🤖</span><%= s.owner_agent_id || "system" %>
                </span>
                <span class="ab-loot-acquired">✦ edinildi · <%= format_time(s.updated_at) %></span>
              </footer>
            </article>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Kategoriye göre "eşya" ikonu, adı ve nadirlik seviyesi — skill kazanmak
  # bir oyunda kalkan/kılıç/ejderha almak gibi görünsün.
  @loot_by_category %{
    "software-development" => {"⚔️", "Kılıç", "epic"},
    "devops" => {"🔧", "Çekiç", "rare"},
    "security" => {"🛡️", "Kalkan", "epic"},
    "research" => {"📜", "Parşömen", "rare"},
    "data" => {"💎", "Mücevher", "rare"},
    "automation" => {"🐉", "Ejderha", "legendary"},
    "workflow" => {"🐉", "Ejderha", "legendary"},
    "communication" => {"📯", "Boru", "common"},
    "design" => {"🎨", "Fırça", "rare"}
  }

  defp loot_info(category) do
    {icon, label, rarity} =
      Map.get(@loot_by_category, category, {"📦", "Eşya", "common"})

    %{icon: icon, label: label, rarity: rarity}
  end

  defp format_time(dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "şimdi"
      diff < 3600 -> "#{div(diff, 60)}dk"
      diff < 86_400 -> "#{div(diff, 3600)}sa"
      diff < 604_800 -> "#{div(diff, 86_400)}g"
      true -> to_string(DateTime.to_date(dt))
    end
  end
end
