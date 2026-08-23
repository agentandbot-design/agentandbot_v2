defmodule AgentbotCore.Modules.Chat.MessageProducer do
  @moduledoc """
  GenStage producer — PubSub'dan gelen event'leri Broadway pipeline'ına besler.

  `pipeline_events` topic'ini dinler. RoomServer her event'i bu topic'e push'lar.
  Producer event'leri internal queue'da tutar, Broadway demand geldikçe teslim eder.

  Back-pressure: Broadway demand'i olmadan event'ler queue'da birikir.
  Queue max boyutu aşıldığında event'ler drop edilir (log'lanır).
  """

  use GenStage
  require Logger

  @max_queue 500

  @doc "Producer'ı başlatır"
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenStage.start_link(__MODULE__, opts, name: name)
  end

  @doc "Pipeline'a manuel event push (test veya direkt kullanım için)"
  def push(message, producer \\ __MODULE__) do
    GenStage.cast(producer, {:push, message})
  end

  # ── GenStage Callbacks ──────────────────────────────────────────

  @impl true
  def init(opts) do
    # PubSub'a subscribe ol — tüm pipeline event'leri buraya gelir
    topic = Keyword.get(opts, :topic, "pipeline_events")
    AgentbotCore.PubSub.subscribe(topic)

    {:producer,
     %{
       queue: :queue.new(),
       demand: 0,
       topic: topic
     }}
  end

  @impl true
  def handle_demand(incoming_demand, state) do
    # Yeni demand'i ekle, queue'dan mümkün olduğunca teslim et
    state = %{state | demand: state.demand + incoming_demand}
    {messages, new_state} = dispatch_pending(state)
    {:noreply, messages, new_state}
  end

  @impl true
  def handle_info({event, payload}, state) do
    # PubSub'dan gelen event — queue'ya ekle
    message = build_broadway_message(event, payload)
    state = enqueue(state, message)

    # Demand varsa hemen teslim et
    {messages, new_state} = dispatch_pending(state)
    {:noreply, messages, new_state}
  end

  @impl true
  def handle_cast({:push, message}, state) do
    state = enqueue(state, message)
    {messages, new_state} = dispatch_pending(state)
    {:noreply, messages, new_state}
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp build_broadway_message(event, payload) do
    %Broadway.Message{
      data: %{
        event: event,
        payload: payload,
        room_id: extract_room_id(payload),
        timestamp: System.monotonic_time(:millisecond)
      },
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  defp extract_room_id(%{room_id: room_id}), do: to_string(room_id)
  defp extract_room_id(%{"room_id" => room_id}), do: to_string(room_id)
  defp extract_room_id(_), do: "unknown"

  defp enqueue(%{queue: queue} = state, message) do
    new_queue = :queue.in(message, queue)

    if :queue.len(new_queue) > @max_queue do
      # Queue dolu — en eski mesajı drop et
      {{:value, _dropped}, trimmed} = :queue.out(new_queue)
      Logger.warning("MessageProducer queue dolu, event drop edildi")
      %{state | queue: trimmed}
    else
      %{state | queue: new_queue}
    end
  end

  defp dispatch_pending(%{demand: 0} = state), do: {[], state}

  defp dispatch_pending(%{queue: queue, demand: demand} = state) do
    case :queue.out(queue) do
      {{:value, message}, new_queue} ->
        {[message], %{state | queue: new_queue, demand: demand - 1}}

      {:empty, _queue} ->
        {[], state}
    end
  end
end
