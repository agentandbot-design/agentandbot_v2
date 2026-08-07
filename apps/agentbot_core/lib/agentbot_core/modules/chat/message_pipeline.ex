defmodule AgentbotCore.Modules.Chat.MessagePipeline do
  @moduledoc """
  Broadway pipeline — agent-hızlı MCP event'lerini insan-hızlı summary'lere dönüştürür.

  ## Akış

  ```
  MessageProducer (GenStage)
      ↓
  Processor (summarize via Summary module)
      ↓
  Batcher (batch by room_id)
      ↓
  BatchProcessor (`human:ROOM_ID` topic'e broadcast)
  ```

  ## Back-pressure

  Broadway otomatik back-pressure uygular:
  - Processor concurrency: 4 (paralel summary)
  - Batch size: 10 (10 event'i tek batch'te işle)
  - Batch timeout: 2s (2 saniyede batch'i flush et)

  ## Event akışı

  RoomServer artık sadece `room:ID` topic'ine broadcast yapar.
  RoomServer ayrıca `pipeline_events` topic'ine de push yapar → MessageProducer alır →
  Pipeline işler → `human:ID` topic'ine summary broadcast eder.
  """

  use Broadway
  require Logger

  alias AgentbotCore.Modules.LLM.Summary
  alias AgentbotCore.PubSub

  @default_batch_size 10
  @default_batch_timeout 2000

  @doc "MessagePipeline GenServer'ı başlatır"
  def start_link(opts \\ []) do
    producer_module = Keyword.get(opts, :producer, AgentbotCore.Modules.Chat.MessageProducer)
    producer_opts = Keyword.get(opts, :producer_opts, [])
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout, @default_batch_timeout)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_module, producer_opts},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 4]
      ],
      batchers: [
        default: [concurrency: 2, batch_size: batch_size, batch_timeout: batch_timeout]
      ]
    )
  end

  # ── Broadway Callbacks ──────────────────────────────────────────

  @impl true
  def handle_message(:default, message, _context) do
    %{event: event, payload: payload} = message.data

    summary = Summary.summarize(event, payload)

    Broadway.Message.update_data(message, fn _data ->
      summary
    end)
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    # Same room_id'ye sahip mesajları grupla
    grouped = Enum.group_by(messages, fn msg -> msg.data.room_id end)

    # Her room için summary batch'ini human:#{room_id} topic'ine broadcast et
    Enum.each(grouped, fn {room_id, room_messages} ->
      summaries = Enum.map(room_messages, & &1.data)

      PubSub.broadcast("human:#{room_id}", "pipeline_summary", %{
        room_id: room_id,
        summaries: summaries,
        count: length(summaries)
      })
    end)

    messages
  end

  @impl true
  def handle_failed(messages, _info) do
    Logger.warning("MessagePipeline batch failed: #{length(messages)} mesaj")

    Enum.each(messages, fn msg ->
      Logger.debug("Failed message: #{inspect(msg.data)}")
    end)

    messages
  end
end
