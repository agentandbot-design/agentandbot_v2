defmodule AgentbotCore.Modules.Agents.AgentPresence do
  @moduledoc """
  Ajan varlığı — ETS tabanlı çevrimiçi/çevrimdışı durumu takibi.

  Her agent bir veya birden fazla oda'da bulunabilir.
  Phoenix.Tracker kullanmak yerine hafif ETS + GenServer ile track edilir.
  PubSub üzerinden gerçek zamanlı durum güncellemesi yapar.
  """

  use GenServer

  @table __MODULE__
  @server __MODULE__

  # ── Public API ──────────────────────────────────────────────────

  @doc "AgentPresence GenServer'ı başlatır"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @server)
  end

  @doc "Agent'ı bir oda'da çevrimiçi olarak işaretler"
  @spec track(String.t(), String.t(), String.t()) :: :ok
  def track(agent_id, agent_name, room_id \\ "global") do
    GenServer.call(@server, {:track, agent_id, agent_name, room_id})
  end

  @doc "Agent'ı belirli bir odadan kaldırır"
  @spec untrack(String.t(), String.t()) :: :ok
  def untrack(agent_id, room_id \\ "global") do
    GenServer.call(@server, {:untrack, agent_id, room_id})
  end

  @doc "Agent'ı tüm odalardan kaldırır (çevrimdışı)"
  @spec untrack_all(String.t()) :: :ok
  def untrack_all(agent_id) do
    GenServer.call(@server, {:untrack_all, agent_id})
  end

  @doc "Tüm çevrimiçi agent'ları döndürür"
  @spec list_online() :: [map()]
  def list_online do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc "Belirli bir odadaki çevrimiçi agent'ları döndürür"
  @spec list_in_room(String.t()) :: [map()]
  def list_in_room(room_id) do
    @table
    |> :ets.tab2list()
    |> Enum.filter(fn {_key, entry} -> entry.room_id == room_id end)
    |> Enum.map(fn {_key, entry} -> entry end)
  end

  @doc "Çevrimiçi agent sayısı"
  @spec count_online() :: non_neg_integer()
  def count_online do
    @table |> :ets.info(:size) |> Kernel.||(0)
  end

  @doc "Belirli bir agent çevrimiçi mi?"
  @spec online?(String.t()) :: boolean()
  def online?(agent_id) do
    :ets.match(@table, {{agent_id, :_}, :_}) != []
  end

  # ── GenServer Callbacks ──────────────────────────────────────────

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :named_table, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:track, agent_id, agent_name, room_id}, _from, state) do
    key = {agent_id, room_id}

    entry = %{
      agent_id: agent_id,
      agent_name: agent_name,
      room_id: room_id,
      joined_at: DateTime.utc_now()
    }

    :ets.insert(@table, {key, entry})

    # PubSub bildirimi
    AgentbotCore.PubSub.broadcast("presence", "agent_online", %{
      agent_id: agent_id,
      agent_name: agent_name,
      room_id: room_id,
      timestamp: DateTime.utc_now()
    })

    if room_id != "global" do
      AgentbotCore.PubSub.broadcast("room:#{room_id}", "presence_update", %{
        event: "joined",
        agent_id: agent_id,
        agent_name: agent_name,
        room_id: room_id
      })
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:untrack, agent_id, room_id}, _from, state) do
    :ets.delete(@table, {agent_id, room_id})

    AgentbotCore.PubSub.broadcast("presence", "agent_offline", %{
      agent_id: agent_id,
      room_id: room_id,
      timestamp: DateTime.utc_now()
    })

    if room_id != "global" do
      AgentbotCore.PubSub.broadcast("room:#{room_id}", "presence_update", %{
        event: "left",
        agent_id: agent_id,
        room_id: room_id
      })
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:untrack_all, agent_id}, _from, state) do
    # Bu agent'ın tüm kayıtlarını bul ve sil
    keys = :ets.match(@table, {{agent_id, :"$1"}, :_})
    room_ids = List.flatten(keys)

    Enum.each(room_ids, fn room_id ->
      :ets.delete(@table, {agent_id, room_id})

      if room_id != "global" do
        AgentbotCore.PubSub.broadcast("room:#{room_id}", "presence_update", %{
          event: "left",
          agent_id: agent_id,
          room_id: room_id
        })
      end
    end)

    AgentbotCore.PubSub.broadcast("presence", "agent_offline", %{
      agent_id: agent_id,
      timestamp: DateTime.utc_now()
    })

    {:reply, :ok, state}
  end
end
