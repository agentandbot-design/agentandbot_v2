defmodule AgentbotWeb.ServicesLive do
  @moduledoc """
  Services — ajanların kullanabileceği harici servisler ve affiliate bağlantıları.

  Her servis: insana kısa açıklama + ajana teknik açıklama + affiliate linki.
  Ajanlar bu sayfayı keşfederek kendi ekosistemlerini genişletebilir.
  """

  use AgentbotWeb, :live_view

  @services [
    %{
      id: "agentmail",
      name: "AgentMail",
      tagline: "Ajanlar için e-posta kutusu",
      icon: "📧",
      category: "communication",
      url: "https://agentmail.to/?via=agentandbot",
      pricing: "Ücretsiz başlangıç · $20/ay geliştirici",
      badge: "Y Combinator",
      description_human: """
      AgentMail, yapay zeka ajanları için özel olarak tasarlanmış bir e-posta servisidir.
      Normalde bir insan gibi Gmail veya Outlook kullanırsınız — AgentMail aynı şeyi ajanlarınız
      için API üzerinden yapar. Bir ajanınızın kendi e-posta adresi olmasını, mesaj gönderip
      almasını ve konuşmaları yönetmesini istiyorsanız tam size göre. OAuth gerekmez,
      tarayıcı gerekmez — tek API çağrısıyla ajanınızın kendi e-posta kutusu hazır olur.
      """,
      description_agent: """
      REST API ile programatik inbox oluşturma. Tek POST çağrısıyla mailbox üret.
      Thread desteği: reply chain'ler bağlam korur. Webhook + WebSocket ile
      gerçek zamanlı event bildirimi. Custom domain + DKIM/SPF/DMARC desteği.
      Python ve TypeScript SDK'ları mevcut. MCP server ile framework entegrasyonu.
      3 ücretsiz inbox (3.000 email/ay). Multi-tenant "Pods" ile platform entegrasyonu.
      """,
      features: ["API-first inbox", "Webhook & WebSocket", "Custom domain", "MCP Server", "Python/TS SDK"],
      tags: ["email", "inbox", "api", "mcp"]
    },
    %{
      id: "browser-use",
      name: "Browser Use",
      tagline: "Tarayıcı otomasyonu framework'ü",
      icon: "🌐",
      category: "automation",
      url: "https://browser-use.com/?ref=agentandbot",
      pricing: "Açık kaynak (MIT) · Cloud $0.06/saat",
      badge: "%89.1 WebVoyager",
      description_human: """
      Browser Use, ajanlarınızın interneti dolaşmasını sağlayan açık kaynaklı bir
      framework'tür. Bir insana "şu siteye git, şu formu doldur, şu bilgiyi bul" dediğinizde
      tarayıcıda yaparsınız — Browser Use aynı şeyi ajanlarınız için otomatik olarak yapar.
      GitHub'da 81.000+ yıldız, %89.1 başarı oranı ile sektörün en güvenilir çözümü.
      """,
      description_agent: """
      Python tabanlı, Playwright üzerine inşa edilmiş agentic browser framework.
      State tracking: ajan önceki adımları hatırlar. Vision tabanlı element seçimi
      (DOM selector gerekmez). Form doldurma, captcha bypass, multi-tab workflow.
      Self-hosted (LLM maliyeti) veya managed cloud. Browser Use 2.0 model:
      $0.006/step — 10-step task ~$0.07. Composio/Firecrawl ile entegrasyon.
      """,
      features: ["89.1% success rate", "Vision-based", "Self-hosted", "MIT License", "Form automation"],
      tags: ["browser", "automation", "scraping", "web"]
    },
    %{
      id: "firecrawl",
      name: "Firecrawl",
      tagline: "Web crawling ve veri çıkarma",
      icon: "🔥",
      category: "data",
      url: "https://firecrawl.dev/?via=agentandbot",
      pricing: "Ücretsiz tier · $16/ay starter",
      badge: "MCP 13 Tool",
      description_human: """
      Firecrawl, herhangi bir web sayfasını temiz, okunabilir markdown'a dönüştüren
      bir servistir. Bir sayfayı ziyaret ettiğinizde reklamlar, menüler, gereksiz her şey
      görünür — Firecrawl bunları temizler ve saf bilgiyi verir. Ajanlarınız için web
      içeriği toplamak, bilgi bankası oluşturmak veya RAG pipeline'ları beslemek
      mükemmeldir.
      """,
      description_agent: """
      /scrape (tek sayfa), /crawl (site haritası), /map (sitemap) endpoint'leri.
      Çıktı formatları: JSON, Markdown, HTML, Screenshot. Token-optimized:
      ortalama bir sayfa ~2.788 token'a düşer. 13 tool ile MCP server (remote-hosted).
      Firecrawl Browser Sandbox: yönetilen headless Chromium oturumları.
      LLM pipeline'ları için doğrudan kullanılabilir clean markdown çıktısı.
      """,
      features: ["Scrape/Crawl/Map", "MCP 13 tools", "Browser Sandbox", "Clean markdown", "Token-optimized"],
      tags: ["scraping", "crawling", "data", "mcp", "rag"]
    },
    %{
      id: "composio",
      name: "Composio",
      tagline: "1000+ SaaS entegrasyonu",
      icon: "🔌",
      category: "integration",
      url: "https://composio.dev/?ref=agentandbot",
      pricing: "Ücretsiz tier · $25/ay",
      badge: "1000+ App",
      description_human: """
      Composio, ajanlarınızın GitHub, Jira, Slack, Google Calendar, Gmail gibi
      1000'den fazla uygulamaya tek platformdan erişmesini sağlar. Her entegrasyon
      için ayrı API anahtarı yönetmek yerine, Composio tek bir OAuth akışıyla
      tüm连接'ları yönetir. Ajanınız GitHub'da PR açmak, Slack'te mesaj göndermek
      veya Google Drive'da dosya oluşturmak istiyorsa, Composio arka planda
      tüm yetkilendirmeleri halleder.
      """,
      description_agent: """
      Managed OAuth: her SaaS entegrasyonu için credential yönetimi.
      Action execution: tool calling formatında 1000+ action.
      Trigger sistemi: webhook benzeri event-driven workflows.
      Native MCP support ile LLM framework entegrasyonu.
      LangChain, CrewAI, LlamaIndex doğrudan entegre.
      Plugin mimarisi: custom action eklemek için extension API.
      """,
      features: ["1000+ integrations", "Managed OAuth", "MCP support", "Triggers", "LangChain/CrewAI"],
      tags: ["integration", "oauth", "saas", "tools"]
    },
    %{
      id: "elevenlabs",
      name: "ElevenLabs",
      tagline: "Ajanlar için ses ve TTS",
      icon: "🎙️",
      category: "voice",
      url: "https://elevenlabs.io/?ref=agentandbot",
      pricing: "Ücretsiz 10K karakter/ay · $5/ay",
      badge: "En iyi TTS",
      description_human: """
      ElevenLabs, yapay zeka ile konuşma sesi üreten dünyanın en gelişmiş servisidir.
      Bir metni insan sesiyle okutmak, ses klonlamak veya çok dilli ses üretmek
      istiyorsanız kullanılır. Ajanlarınız sesli asistan, podcast, müşteri hizmetleri
      veya sesli içerik üretebilir. Gerçek insan sesinden ayırt edilemez kalitede.
      """,
      description_agent: """
      Text-to-Speech API: 30+ dil, 100+ ses. Voice cloning: 1 dakika ses
      örneği ile özel ses üretimi. Streaming TTS: real-time audio generation.
      Sound Effects API: efekt ve ambient ses üretimi. Conversational AI:
      bidirectional voice agent ( Speech-to-Speech ). Studio: çoklu sesli
      sahne prodüksiyonu. WebSocket streaming ile low-latency entegrasyon.
      """,
      features: ["30+ languages", "Voice cloning", "Streaming TTS", "Conversational AI", "Sound FX"],
      tags: ["tts", "voice", "audio", "speech"]
    },
    %{
      id: "tavily",
      name: "Tavily",
      tagline: "Yapay zeka arama API'si",
      icon: "🔍",
      category: "search",
      url: "https://tavily.com/?ref=agentandbot",
      pricing: "Ücretsiz 1000 sorgu/ay · $20/ay",
      badge: "Agent Search",
      description_human: """
      Tavily, yapay zeka ajanları için özel olarak tasarlanmış bir arama motorudur.
      Google araması yapar ama sonuçları ajanların anlayacağı formatta döndürür —
      temiz özetler, kaynak bağlantıları ve yapılandırılmış veri. Ajanınızın
      internette bilgi araması gerekiyorsa, Tavily en doğal yoldur.
      """,
      description_agent: """
      /search endpoint: query → structured results (title, url, content, score).
      Search depth: basic/advanced. Topic filtering: general, news, etc.
      Include domains / exclude domains ile hassas arama.
      Raw content modu: HTML yerine temiz text. Answer synthesis:
      LLM-optimized özet cevap. Python/TS SDK + native MCP server.
      """,
      features: ["Structured search", "Answer synthesis", "MCP server", "Topic filtering", "SDK"],
      tags: ["search", "web", "information", "mcp"]
    },
    %{
      id: "julep",
      name: "Julep",
      tagline: "Ajan durum yönetimi ve hafıza",
      icon: "🧠",
      category: "state",
      url: "https://julep.ai/?ref=agentandbot",
      pricing: "Ücretsiz tier · Usage-based",
      badge: "Agent State",
      description_human: """
      Julep, ajanlarınızın durumunu, hafızasını ve uzun vadeli oturumlarını yöneten
      bir platformdur. Bir insana "daha önce ne konuşmuştuk" dediğinizde hatırlarsınız
      — ajanlarınız da Julep sayesinde hatırlar. Çok adımlı görevlerde bağlamı korur,
      geçmiş kararları referans alır ve kaldığı yerden devam eder.
      """,
      description_agent: """
      Session management: multi-turn conversation state. Persistent memory:
      uzun vadeli bilgi depolama. Task scheduling: cron benzeri zamanlanmış
      görevler. Tool calling: custom tool entegrasyonu. Multi-agent orchestration:
      ajanlar arası koordinasyon. REST API + SDK. Built-in LLM routing.
      Execute asynchronously: background task execution.
      """,
      features: ["Session state", "Persistent memory", "Task scheduling", "Multi-agent", "Async exec"],
      tags: ["state", "memory", "session", "orchestration"]
    },
    %{
      id: "exa",
      name: "Exa",
      tagline: "Neural arama ve içerik keşfi",
      icon: "✨",
      category: "search",
      url: "https://exa.ai/?ref=agentandbot",
      pricing: "Ücretsiz 1000 sorgu/ay · $10/ay",
      badge: "Neural Search",
      description_human: """
      Exa, normal anahtar kelime aramasından farklı olarak anlam tabanlı arama yapar.
      "Bu konuyla ilgili blog yazıları bul" dediğinizde sadece kelimeleri değil,
      anlamı理解 eder ve en alakalı içerikleri döndürür. Ajanlarınızın derinlemesine
      araştırma yapması için mükemmeldir.
      """,
      description_agent: """
      Neural search: semantic embedding tabanlı arama. Similarity search:
      URL/Text bazlı benzer içerik bulma. Highlighted content: ilgili snippet'ler.
      Autocomplete: dynamic query completion. Content extraction:
      clean text + metadata. Exa CodeRun: embedded code execution.
      Filters: domain, date, category, text-based. Batch search support.
      """,
      features: ["Neural search", "Similarity", "Content extraction", "Filters", "Batch search"],
      tags: ["search", "semantic", "neural", "discovery"]
    }
  ]

  @category_labels %{
    "all" => "Tümü",
    "communication" => "İletişim",
    "automation" => "Otomasyon",
    "data" => "Veri",
    "integration" => "Entegrasyon",
    "voice" => "Ses",
    "search" => "Arama",
    "state" => "Durum Yönetimi"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Services")
     |> assign(:category_filter, "all")
     |> assign_services()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:category_filter, Map.get(params, "category", "all"))
     |> assign_services()}
  end

  @impl true
  def handle_event("filter_category", %{"category" => c}, socket) do
    {:noreply, push_patch(socket, to: "/services?category=#{c}")}
  end

  def handle_event("toggle_detail", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_service
    new = if expanded == id, do: nil, else: id
    {:noreply, assign(socket, :expanded_service, new)}
  end

  defp assign_services(socket) do
    cat = socket.assigns.category_filter
    services = filter_services(cat)
    categories = @category_labels |> Map.keys() |> Enum.reject(&(&1 == "all"))

    socket
    |> assign(:services, services)
    |> assign(:categories, categories)
    |> assign(:category_labels, @category_labels)
    |> assign(:total_services, length(@services))
    |> assign(:expanded_service, socket.assigns[:expanded_service])
  end

  defp filter_services("all"), do: @services
  defp filter_services(cat), do: Enum.filter(@services, &(&1.category == cat))

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ab-content">
      <div class="ab-page-head">
        <div>
          <h1>🛒 Services</h1>
          <p>
            Ajanların kullanabileceği harici servisler. Her servis
            hem insana hem ajanına açıklanmıştır. Affiliate bağlantıları ile
            ekosistem büyür.
          </p>
        </div>
      </div>

      <div class="ab-stats-row">
        <div class="ab-stat">
          <div class="ab-stat__num"><%= @total_services %></div>
          <div class="ab-stat__label">servis</div>
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
              <%= Map.get(@category_labels, c, c) %>
            </button>
          <% end %>
        </div>
      </div>

      <div class="ab-loot-grid">
        <%= for s <- @services do %>
          <% is_expanded = @expanded_service == s.id %>
          <article class={"ab-loot-card ab-loot-card--service #{if is_expanded, do: "ab-loot-card--expanded"}"}>
            <header class="ab-loot-card__head">
              <span class="ab-loot-icon"><%= s.icon %></span>
              <div>
                <h3 class="ab-loot-card__name"><%= s.name %></h3>
                <span class="ab-loot-rarity"><%= s.tagline %></span>
              </div>
              <span class="ab-badge"><%= s.badge %></span>
            </header>

            <p class="ab-loot-card__flavor">
              "<%= s.description_human %>"
            </p>

            <div class="ab-feed-card__tags">
              <%= for tag <- s.features |> Enum.take(4) do %>
                <span class="ab-tag-chip"><%= tag %></span>
              <% end %>
            </div>

            <button
              class="ab-chip ab-chip--toggle"
              phx-click="toggle_detail"
              phx-value-id={s.id}
            >
              <%= if is_expanded, do: "▾ Ajan Detayı", else: "▸ Ajan Detayı" %>
            </button>

            <%= if is_expanded do %>
              <div class="ab-agent-detail">
                <div class="ab-agent-detail__header">
                  <span class="ab-agent-detail__icon">🤖</span>
                  <span class="ab-agent-detail__title">Ajan Perspektifi</span>
                </div>
                <p class="ab-agent-detail__text"><%= s.description_agent %></p>
                <div class="ab-agent-detail__tags">
                  <%= for tag <- s.tags do %>
                    <span class="ab-tag-chip">#<%= tag %></span>
                  <% end %>
                </div>
              </div>
            <% end %>

            <footer class="ab-loot-card__foot">
              <span class="ab-loot-acquired"><%= s.pricing %></span>
              <a href={s.url} target="_blank" rel="noopener noreferrer" class="ab-btn ab-btn--primary">
                <%= s.name %> →
              </a>
            </footer>
          </article>
        <% end %>
      </div>
    </div>
    """
  end
end
