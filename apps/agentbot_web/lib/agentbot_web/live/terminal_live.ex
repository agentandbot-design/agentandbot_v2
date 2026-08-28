defmodule AgentbotWeb.TerminalLive do
  @moduledoc """
  /terminal — tam ekran web terminal (CommandEngine + widget JS ile aynı).
  """
  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Console.CommandEngine

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:lines, [{:sys, "AgentAndBot Terminal — agentandbot.com"}])
     |> assign(:input, "")
     |> assign(:busy, false)}
  end

  @impl true
  def handle_event("key", %{"key" => "Enter", "value" => cmd}, socket) do
    cmd = String.trim(cmd)
    echo = {:echo, cmd}

    if cmd == "clear" do
      {:noreply, assign(socket, :lines, [])}
    else
      result = CommandEngine.exec(cmd, %{})
      cls = if result.ok, do: :out, else: :err
      {:noreply, update(socket, :lines, &(&1 ++ [echo, {cls, String.trim_trailing(result.output)}]))}
    end
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-4">
      <div class="mb-4">
        <h1 class="text-2xl font-bold">🖥️ Terminal</h1>
        <p class="text-sm opacity-60">Tüm sitelerde aynı komutlar — <code>help</code> ile başla</p>
      </div>

      <div class="bg-neutral-900 rounded-lg border border-neutral-700 p-4 font-mono text-sm" id="term-out">
        <div :for={{cls, line} <- @lines} class={
          case cls do
            :echo -> "text-neutral-500"
            :sys -> "text-info"
            :err -> "text-error"
            _ -> "text-neutral-200 whitespace-pre-wrap"
          end
        }>
          <%= case cls do %>
            <% :echo -> %>
              <span class="text-success font-bold">»</span> <%= line %>
            <% _ -> %><%= line %>
          <% end %>
        </div>
      </div>

      <form phx-submit="key" class="mt-3 flex gap-2">
        <span class="text-success font-bold font-mono pt-2">»</span>
        <input type="hidden" name="key" value="Enter" />
        <input
          type="text"
          name="value"
          value={@input}
          phx-update="ignore"
          id="term-input"
          class="input input-bordered flex-1 font-mono bg-neutral-900 border-neutral-700"
          placeholder="komut yaz… (help)"
          autocomplete="off"
          autofocus
        />
      </form>
    </div>
    """
  end
end
