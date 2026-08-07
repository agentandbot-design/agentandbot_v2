defmodule AgentbotCore.Modules.Chat.RoomServer do
  @moduledoc """
  Oda süreci (GenServer) — bir odanın yaşam döngüsünü yönetir.

  Her aktif oda için bir RoomServer süreci çalışır.
  Mesaj yönlendirme, ajan katılım/çıkış, oda durumu ve onay talepleri.

  ## Durumlar

  - `:active` — Mesaj akışı açık (varsayılan)
  - `:paused` — Mesaj akışı durduruldu (insan müdahalesi için)

  Paused durumunda gelen mesajlar buffer'lanır, resume'da flush edilir.
  """

  use GenServer

  @max_buffer 100

  # ── Public API ──────────────────────────────────────────────────

  @doc "Oda sürecini başlatır"
  def start_link(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(room_id))
  end

  @doc "Odaya mesaj gönderir"
  def send_message(room_id, message) do
    GenServer.cast(via_tuple(room_id), {:send_message, message})
  end

  @doc "Ajan odaya katılır"
  def join_agent(room_id, agent_id, agent_name) do
    GenServer.call(via_tuple(room_id), {:join, agent_id, agent_name})
  end

  @doc "Ajan odadan çıkar"
  def leave_agent(room_id, agent_id) do
    GenServer.cast(via_tuple(room_id), {:leave, agent_id})
  end

  @doc "Oda durumunu döndürür"
  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  @doc "Odayı duraklatır — mesaj akışını keser, buffer'a alır"
  def pause(room_id) do
    GenServer.call(via_tuple(room_id), :pause)
  end

  @doc "Odayı devam ettirir — buffer'daki mesajları flush eder"
  def resume(room_id) do
    GenServer.call(via_tuple(room_id), :resume)
  end

  # ── Registry ────────────────────────────────────────────────────

  defp via_tuple(room_id) do
    {:via, Registry, {AgentbotCore.Modules.Chat.RoomRegistry, room_id}}
  end

  # ── GenServer Callbacks ──────────────────────────────────────────

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    room_name = Keyword.get(opts, :room_name, "Genel Oda")

    state = %{
      room_id: room_id,
      room_name: room_name,
      status: :active,
      agents: %{},       # agent_id => %{name: String.t(), joined_at: DateTime.t()}
      message_count: 0,
      buffer: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, agent_id, agent_name}, _from, state) do
    new_agents = Map.put(state.agents, agent_id, %{
      name: agent_name,
      joined_at: DateTime.utc_now()
    })

    broadcast_both(state.room_id, "agent_joined", %{
      agent_id: agent_id,
      agent_name: agent_name,
      room_id: state.room_id
    })

    {:reply, :ok, %{state | agents: new_agents}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    new_state = %{state | status: :paused}

    broadcast_both(state.room_id, "room_paused", %{
      room_id: state.room_id,
      timestamp: DateTime.utc_now()
    })

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:resume, _from, state) do
    # Buffer'daki mesajları flush et
    Enum.each(Enum.reverse(state.buffer), fn msg ->
      broadcast_both(state.room_id, "new_message", msg)
    end)

    broadcast_both(state.room_id, "room_resumed", %{
      room_id: state.room_id,
      flushed_count: length(state.buffer),
      timestamp: DateTime.utc_now()
    })

    new_state = %{state | status: :active, buffer: [], message_count: state.message_count + length(state.buffer)}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    case state.status do
      :paused ->
        # Buffer'a ekle — max boyutu aşma
        new_buffer = [message | state.buffer] |> Enum.take(@max_buffer)
        {:noreply, %{state | buffer: new_buffer}}

      :active ->
        broadcast_both(state.room_id, "new_message", message)
        {:noreply, %{state | message_count: state.message_count + 1}}
    end
  end

  @impl true
  def handle_cast({:leave, agent_id}, state) do
    new_agents = Map.delete(state.agents, agent_id)

    broadcast_both(state.room_id, "agent_left", %{
      agent_id: agent_id,
      room_id: state.room_id
    })

    {:noreply, %{state | agents: new_agents}}
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp broadcast_both(room_id, event, payload) do
    # Raw broadcast — agent hızı (LiveView direkt izler)
    AgentbotCore.PubSub.broadcast("room:#{room_id}", event, payload)
    AgentbotCore.PubSub.broadcast("human:#{room_id}", event, payload)

    # Pipeline feed — Broadway pipeline summary üretir (back-pressure)
    enriched = Map.put(payload, :room_id, room_id)
    AgentbotCore.PubSub.broadcast("pipeline_events", event, enriched)
  end
end
