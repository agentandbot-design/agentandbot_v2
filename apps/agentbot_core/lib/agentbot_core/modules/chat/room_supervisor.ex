defmodule AgentbotCore.Modules.Chat.RoomSupervisor do
  @moduledoc """
  Oda süpervizörü — DynamicSupervisor ile oda süreçlerini yönetir.

  Her yeni oda için bir RoomServer GenServer başlatır.
  """

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_room(room_id, room_name \\ nil) do
    spec = %{
      id: AgentbotCore.Modules.Chat.RoomServer,
      start: {AgentbotCore.Modules.Chat.RoomServer, :start_link, [room_id: room_id, room_name: room_name]}
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_room(room_id) do
    case Registry.lookup(AgentbotCore.Modules.Chat.RoomRegistry, room_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
