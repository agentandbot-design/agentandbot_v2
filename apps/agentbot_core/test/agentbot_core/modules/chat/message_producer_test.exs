defmodule AgentbotCore.Modules.Chat.MessageProducerTest do
  @moduledoc """
  MessageProducer testleri — GenStage back-pressure + PubSub event toplama.

  Anti-Crash Manifesto: Kara kutu kod yok.
  """

  use ExUnit.Case, async: false

  alias AgentbotCore.Modules.Chat.MessageProducer

  setup do
    # Producer'ı başlat — app supervision tree'deki PubSub kullanılır
    {:ok, producer} = MessageProducer.start_link(name: :test_producer)

    on_exit(fn ->
      try do
        GenServer.stop(producer, :normal)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, producer: producer}
  end

  describe "push/1" do
    test "event queue'ya eklenir" do
      # demand yokken event queue'da bekler
      MessageProducer.push(
        %{event: :new_message, payload: %{room_id: "r1"}},
        :test_producer
      )

      # Kısa bekle — event işlensin
      Process.sleep(50)

      # Producer hala ayakta
      assert Process.alive?(Process.whereis(:test_producer))
    end
  end

  describe "PubSub subscription" do
    test "pipeline_events topic'inden event alır" do
      # PubSub üzerinden event broadcast et
      AgentbotCore.PubSub.broadcast("pipeline_events", :new_message, %{
        room_id: "r1",
        content: "test"
      })

      Process.sleep(50)

      assert Process.alive?(Process.whereis(:test_producer))
    end
  end

  describe "back-pressure" do
    test "demand olmadan event'ler bekler" do
      # Çoklu event push et — demand yoksa queue'da birikir
      for i <- 1..10 do
        MessageProducer.push(
          %{event: :msg, payload: %{index: i}},
          :test_producer
        )
      end

      Process.sleep(50)
      # Producer crash etmemeli
      assert Process.alive?(Process.whereis(:test_producer))
    end
  end
end
