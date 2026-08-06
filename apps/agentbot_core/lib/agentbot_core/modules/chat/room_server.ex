defmodule AgentbotCore.Modules.Chat.RoomServer do
  @moduledoc """
  Oda süreci (GenServer) — bir odanın yaşam döngüsünü yönetir.

  Her aktif oda için bir RoomServer süreci çalışır.
  Mesaj yönlendirme, ajan katılım/çıkış ve oda durumu yönetimi.
  """

  use GenServer

  # Public API

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

  # Registry via tuple
  defp via_tuple(room_id) do
    {:via, Registry, {AgentbotCore.Modules.Chat.RoomRegistry, room_id}}
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    room_name = Keyword.get(opts, :room_name, "Genel Oda")

    state = %{
      room_id: room_id,
      room_name: room_name,
      agents: %{},       # agent_id => %{name: String.t(), joined_at: DateTime.t()}
      message_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, agent_id, agent_name}, _from, state) do
    new_agents = Map.put(state.agents, agent_id, %{
      name: agent_name,
      joined_at: DateTime.utc_now()
    })

    # PubSub'a katılım bildirimi yayınla — dual topic
    AgentbotCore.PubSub.broadcast(
      "room:#{state.room_id}",
      "agent_joined",
      %{agent_id: agent_id, agent_name: agent_name, room_id: state.room_id}
    )
    # Human topic — daha yavaş ama insan-okur format
    AgentbotCore.PubSub.broadcast(
      "human:#{state.room_id}",
      "agent_joined",
      %{agent_id: agent_id, agent_name: agent_name, room_id: state.room_id}
    )

    {:reply, :ok, %{state | agents: new_agents}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    # PubSub'a mesaj yayınla — dual topic (agent hız + human okunur)
    AgentbotCore.PubSub.broadcast(
      "room:#{state.room_id}",
      "new_message",
      message
    )
    AgentbotCore.PubSub.broadcast(
      "human:#{state.room_id}",
      "new_message",
      message
    )

    {:noreply, %{state | message_count: state.message_count + 1}}
  end

  @impl true
  def handle_cast({:leave, agent_id}, state) do
    new_agents = Map.delete(state.agents, agent_id)

    # PubSub'a çıkış bildirimi yayınla — dual topic
    AgentbotCore.PubSub.broadcast(
      "room:#{state.room_id}",
      "agent_left",
      %{agent_id: agent_id, room_id: state.room_id}
    )
    AgentbotCore.PubSub.broadcast(
      "human:#{state.room_id}",
      "agent_left",
      %{agent_id: agent_id, room_id: state.room_id}
    )

    {:noreply, %{state | agents: new_agents}}
  end
end
