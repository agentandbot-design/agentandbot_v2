defmodule AgentbotCore.Modules.Chat.RoomRegistry do
  @moduledoc """
  Oda kayıt defteri — RoomServer süreçlerini isimle bulur.
  """

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def via_tuple(room_id) do
    {:via, Registry, {__MODULE__, room_id}}
  end

  def lookup(room_id) do
    Registry.lookup(__MODULE__, room_id)
  end
end
