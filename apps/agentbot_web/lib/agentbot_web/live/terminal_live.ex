defmodule AgentbotWeb.TerminalLive do
  @moduledoc """
  /terminal — phosphor CRT terminal (Kimsufi ilhamlı, bauhaus: saf CSS).
  """
  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Console.CommandEngine

  @ascii_banner """
       _                    _   _               _             _
      / \\   __ _  ___ _ __ | |_(_) ___ _    ___| | __ _ _   _| | __ _  __ _
     / _ \\ / _` |/ _ \\ '_ \\| __| |/ _ \\ |_ / _ \\ |/ _` | | | | |/ _` |/ _` |
    / ___ \\ (_| |  __/ | | | |_| |  __/ |_  __/ | (_| | |_| | | (_| | (_| |
   /_/   \\_\\__, |\\___|_| |_|\\__|_|\\___|\\__/\\___|_|\\__,_|\\__,_|_|\\__,_|\\__,_|
           |___/
  """

  @quick_cmds ["help", "agents online", "rooms", "task list", "stats", "memory search"]

  @impl true
  def mount(_params, _session, socket) do
    boot = [
      {:dim, "AAB-TERM BIOS v1.2 — phosphor module loaded"},
      {:ok2, "memory: 384-dim embedder ..... OK"},
      {:ok2, "fusion search (RRF k=60) ..... OK"},
      {:ok2, "agent mesh: 17 registered .... OK"},
      {:dim, "boot complete — #{Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M UTC")}"},
      {:banner, nil}
    ]

    {:ok,
     socket
     |> assign(:lines, boot)
     |> assign(:input, "")
     |> assign(:hist_idx, nil)
     |> assign(:history, [])}
  end

  @impl true
  def handle_event("key", %{"key" => "Enter", "value" => cmd}, socket) do
    cmd = String.trim(cmd)
    echo = {:echo, cmd}

    cond do
      cmd == "" ->
        {:noreply, update(socket, :lines, &(&1 ++ [echo]))}

      cmd == "clear" ->
        {:noreply, assign(socket, :lines, [{:banner, nil}])}

      true ->
        result = CommandEngine.exec(cmd, %{})
        cls = if result.ok, do: :out, else: :err
        out = String.trim_trailing(result.output)

        lines =
          socket.assigns.lines ++
            [echo, {cls, out}] ++
            if(String.contains?(cmd, "council ask"),
              do: [{:dim, "(yanıtlar agent'lardan geldikçe /api/council/:id'de görünür)"}],
              else: []
            )

        {:noreply,
         socket
         |> assign(:lines, lines)
         |> assign(:history, socket.assigns.history ++ [cmd])
         |> assign(:hist_idx, nil)}
    end
  end

  def handle_event("key", %{"key" => "ArrowUp", "value" => _}, socket) do
    hist = socket.assigns.history
    idx = socket.assigns.hist_idx

    cond do
      hist == [] ->
        {:noreply, socket}

      is_nil(idx) ->
        {:noreply,
         socket |> assign(:hist_idx, length(hist) - 1) |> assign(:input, Enum.at(hist, -1))}

      idx > 0 ->
        {:noreply, socket |> assign(:hist_idx, idx - 1) |> assign(:input, Enum.at(hist, idx - 1))}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("key", %{"key" => "ArrowDown", "value" => _}, socket) do
    hist = socket.assigns.history
    idx = socket.assigns.hist_idx

    cond do
      is_nil(idx) ->
        {:noreply, socket}

      idx < length(hist) - 1 ->
        {:noreply, socket |> assign(:hist_idx, idx + 1) |> assign(:input, Enum.at(hist, idx + 1))}

      true ->
        {:noreply, socket |> assign(:input, "") |> assign(:hist_idx, nil)}
    end
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-4">
      <div class="mb-3 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">🖥️ Terminal</h1>
          <p class="text-sm opacity-60 font-mono">phosphor CRT · Ctrl+K her sitede aynı komutlar</p>
        </div>
        <a href="/api" class="btn btn-outline btn-sm font-mono">API →</a>
      </div>

      <div class="term-root term-fullscreen" id="aabterm">
        <div class="term-titlebar">
          <div class="flex items-center gap-3">
            <div class="term-dots"><span class="term-dot r"></span><span class="term-dot y"></span><span class="term-dot g"></span></div>
            <span class="term-titlebar-text">agent@agentandbot: ~/console</span>
          </div>
          <span class="term-titlebar-badge">PROTOCOL v1</span>
        </div>

        <div class="term-body" id="term-body" phx-hook="TermScroll">
          <div :for={{cls, text} <- @lines} class={line_class(cls)}>
            <%= case cls do %>
              <% :banner -> %><pre class="term-ascii"><%= @banner %></pre>
              <% :echo -> %><span class="p-user">agent</span><span class="p-sep">@aab:~$</span> <span class="p-cmd"><%= text %></span>
              <% _ -> %><%= text %>
            <% end %>
          </div>
        </div>

        <div class="term-input-area">
          <div class="term-cat" aria-hidden="true">
            <svg viewBox="0 0 160 100" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
              <path d="M138,22 C155,26 162,42 156,58 C151,70 140,68 142,80 C143,90 152,92 150,98"
                    fill="none" stroke="currentColor" stroke-width="9" stroke-linecap="round" />
              <rect x="46" y="26" width="8" height="46" rx="4" />
              <rect x="60" y="26" width="8" height="52" rx="4" />
              <rect x="122" y="24" width="9" height="34" rx="4.5" />
              <path d="M8,26 L14,4 L21,22 L27,8 L34,24 C40,27 44,28 50,28
                       C70,10 100,6 120,12 C132,16 138,20 140,24
                       C130,30 90,30 50,30 C30,30 16,29 8,26 Z" />
            </svg>
          </div>
          <form phx-submit="key" class="term-input-line">
            <input type="hidden" name="key" value="Enter" />
            <span class="p-user">agent</span><span class="p-sep">@aab:~$</span>
            <input
              type="text"
              name="value"
              id="term-input"
              value={@input}
              phx-update="ignore"
              class="term-input"
              placeholder="komut yaz — help"
              autocomplete="off"
              spellcheck="false"
              autofocus
            />
          </form>
          <div class="term-quick">
            <button :for={qc <- @quick} type="button" class="term-chip" phx-click={JS.push("key", value: %{key: "Enter", value: qc})}><%= qc %></button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp line_class(:banner), do: "term-line"
  defp line_class(:echo), do: "term-line l-prompt"
  defp line_class(:out), do: "term-line l-out"
  defp line_class(:err), do: "term-line l-err"
  defp line_class(:sys), do: "term-line l-sys"
  defp line_class(:dim), do: "term-line l-dim"
  defp line_class(:ok2), do: "term-line l-success"
  defp line_class(_), do: "term-line l-out"

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(assign(socket, :banner, @ascii_banner), :quick, @quick_cmds)}
  end
end
