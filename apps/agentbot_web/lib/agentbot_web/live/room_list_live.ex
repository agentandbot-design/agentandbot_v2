defmodule AgentbotWeb.RoomListLive do
  @moduledoc "Oda listesi — yeni oda oluşturma"

  use AgentbotWeb, :live_view

  alias AgentbotCore.Modules.Chat.Room

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: AgentbotCore.PubSub.subscribe("rooms")

    {:ok,
     socket
     |> assign(:rooms, list_rooms())
     |> assign(:form, to_form(%{}))}
  end

  @impl true
  def handle_event("create_room", params, socket) do
    name = Map.get(params, "name", "")
    desc = Map.get(params, "description", "")

    case Room.create(%{name: name, description: desc}) do
      {:ok, room} ->
        AgentbotCore.PubSub.broadcast("rooms", "room_created", room)

        {:noreply,
         socket
         |> put_flash(:info, "Oda oluşturuldu: #{room.name}")
         |> assign(:rooms, list_rooms())
         |> assign(:form, to_form(%{}))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Oda oluşturulamadı")}
    end
  end

  @impl true
  def handle_info({:room_created, room}, socket) do
    {:noreply, assign(socket, :rooms, [room | socket.assigns.rooms])}
  end

  defp list_rooms, do: Room.list_active()
end
