defmodule AgentbotWeb.KanbanCalendarComponent do
  @moduledoc """
  Kanban Calendar görünümü — LiveComponent.
  Ana KanbanLive'dan bağımsız, kendi HTML'i derlenir.
  """

  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    tasks = assigns.tasks || []
    month = assigns.month || Date.utc_today()
    on_task_click = assigns[:on_task_click] || "open_detail"

    socket =
      socket
      |> assign(:tasks, tasks)
      |> assign(:month, month)
      |> assign(:on_task_click, on_task_click)
      |> assign_new(:cal, fn -> build_calendar(tasks, month) end)
      |> assign(:cal, build_calendar(tasks, month))

    {:ok, socket}
  end

  @impl true
  def handle_event("cal_prev", _, socket) do
    prev = shift_month(socket.assigns.month, -1)
    {:noreply, assign(socket, month: prev, cal: build_calendar(socket.assigns.tasks, prev))}
  end

  def handle_event("cal_next", _, socket) do
    next = shift_month(socket.assigns.month, 1)
    {:noreply, assign(socket, month: next, cal: build_calendar(socket.assigns.tasks, next))}
  end

  def handle_event("cal_today", _, socket) do
    today = Date.utc_today()
    {:noreply, assign(socket, month: today, cal: build_calendar(socket.assigns.tasks, today))}
  end

  defp shift_month(date, delta) do
    %{year: y, month: m, day: d} = date
    total = y * 12 + (m - 1) + delta
    new_y = div(total, 12)
    new_m = rem(total, 12) + 1
    max_d = Date.days_in_month(Date.new!(new_y, new_m, 1))
    Date.new!(new_y, new_m, min(d, max_d))
  end

  defp build_calendar(tasks, month_date) do
    first = %{month_date | day: 1}
    last_day = Date.days_in_month(first)
    last = %{first | day: last_day}

    days = Date.range(first, last) |> Enum.to_list()

    by_day =
      tasks
      |> Enum.filter(fn t -> t.deadline_at != nil end)
      |> Enum.group_by(fn t -> t.deadline_at |> DateTime.to_date() end)
      |> Map.new(fn {d, ts} -> {d, Enum.sort_by(ts, & &1.priority, :desc)} end)

    leading_blanks = Date.day_of_week(first) - 1
    today = Date.utc_today()

    pad_before = List.duplicate(:blank, leading_blanks)
    cells = pad_before ++ Enum.map(days, fn d -> {:day, d, Map.get(by_day, d, [])} end)
    pad_after_count = rem(length(cells), 7)
    pad_after = if pad_after_count == 0, do: [], else: List.duplicate(:blank, 7 - pad_after_count)
    all_cells = cells ++ pad_after

    weeks =
      all_cells
      |> Enum.chunk_every(7)
      |> Enum.map(fn row ->
        Enum.map(row, fn
          :blank -> :blank
          {:day, d, ts} -> {d, ts, d == today}
        end)
      end)

    %{
      year: first.year,
      month: first.month,
      month_name: month_name(first.month),
      weeks: weeks,
      tasks_with_deadline: Enum.filter(tasks, & &1.deadline_at),
      tasks_no_deadline: Enum.reject(tasks, & &1.deadline_at)
    }
  end

  defp month_name(1), do: "Ocak"
  defp month_name(2), do: "Şubat"
  defp month_name(3), do: "Mart"
  defp month_name(4), do: "Nisan"
  defp month_name(5), do: "Mayıs"
  defp month_name(6), do: "Haziran"
  defp month_name(7), do: "Temmuz"
  defp month_name(8), do: "Ağustos"
  defp month_name(9), do: "Eylül"
  defp month_name(10), do: "Ekim"
  defp month_name(11), do: "Kasım"
  defp month_name(12), do: "Aralık"

  defp status_color("open"), do: "bg-sky-400"
  defp status_color("assigned"), do: "bg-indigo-400"
  defp status_color("in_progress"), do: "bg-amber-400"
  defp status_color("review"), do: "bg-purple-400"
  defp status_color("completed"), do: "bg-emerald-400"
  defp status_color(_), do: "bg-rose-400"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <button phx-click="cal_prev" phx-target={@myself} class="px-3 py-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 border border-neutral-700 text-neutral-300 transition cursor-pointer">‹</button>
          <button phx-click="cal_today" phx-target={@myself} class="px-3 py-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 border border-neutral-700 text-neutral-300 text-sm transition cursor-pointer">Bugün</button>
          <button phx-click="cal_next" phx-target={@myself} class="px-3 py-2 rounded-lg bg-neutral-800 hover:bg-neutral-700 border border-neutral-700 text-neutral-300 transition cursor-pointer">›</button>
          <h2 class="text-xl font-bold text-neutral-100 ml-3">
            <%= @cal.month_name %> <%= @cal.year %>
          </h2>
        </div>
        <div class="text-sm text-neutral-400">
          <%= length(@cal.tasks_with_deadline) %> deadline'lı ·
          <%= length(@cal.tasks_no_deadline) %> deadline'sız
        </div>
      </div>

      <div class="grid grid-cols-7 gap-1 mb-1">
        <%= for d <- ~w(Pzt Sal Çar Per Cum Cmt Paz) do %>
          <div class="text-center text-xs uppercase tracking-wider text-neutral-500 font-medium py-2">
            <%= d %>
          </div>
        <% end %>
      </div>

      <div class="grid grid-cols-7 gap-1 bg-neutral-900 border border-neutral-800 rounded-xl p-2">
        <%= for week <- @cal.weeks do %>
          <%= for cell <- week do %>
              <%= if cell == :blank do %>
                <div class="h-28 bg-transparent"></div>
              <% else %>
                <% {d, ts, is_today} = cell %>
                <div class={if is_today, do: "h-28 bg-indigo-900/30 border border-indigo-500/50 rounded p-1 overflow-y-auto", else: "h-28 bg-neutral-800/40 border border-neutral-800 rounded p-1 overflow-y-auto hover:bg-neutral-800/70"}>
                  <div class="flex items-center justify-between mb-1">
                    <span class={if is_today, do: "text-xs font-bold text-indigo-300 bg-indigo-500/20 px-1.5 rounded", else: "text-xs text-neutral-500"}>
                      <%= d.day %>
                    </span>
                    <%= if length(ts) > 2 do %>
                      <span class="text-[10px] text-neutral-500">+<%= length(ts) - 2 %></span>
                    <% end %>
                  </div>
                  <div class="space-y-1">
                    <%= for task <- Enum.take(ts, 3) do %>
                      <button
                        phx-click={@on_task_click}
                        phx-value-id={task.id}
                        class={if task.visibility == "private", do: "w-full text-left text-[11px] bg-amber-900/40 border border-amber-700/40 rounded px-1.5 py-1 hover:bg-amber-800/60 truncate text-amber-100", else: "w-full text-left text-[11px] bg-neutral-700/70 border border-neutral-600/50 rounded px-1.5 py-1 hover:bg-neutral-700 truncate text-neutral-200"}
                        title={task.title}
                      >
                        <span class={"inline-block w-1.5 h-1.5 rounded-full mr-1 " <> status_color(task.status)}></span>
                        <%= task.title %>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
        <% end %>
      </div>

      <%= if @cal.tasks_no_deadline != [] do %>
        <div class="mt-5 bg-neutral-900/90 border border-neutral-800 rounded-xl p-4">
          <h3 class="text-sm font-semibold text-neutral-300 mb-3 flex items-center gap-2">
            <span>📌</span> Deadlinesız
            <span class="text-xs text-neutral-500 font-normal">(<%= length(@cal.tasks_no_deadline) %> kart)</span>
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
            <%= for task <- @cal.tasks_no_deadline do %>
              <button
                phx-click={@on_task_click}
                phx-value-id={task.id}
                class="text-left bg-neutral-800/70 hover:bg-neutral-800 border border-neutral-700 rounded-lg p-2 text-xs text-neutral-200"
              >
                <span class={"inline-block w-1.5 h-1.5 rounded-full mr-1 " <> status_color(task.status)}></span>
                <%= task.title %>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
