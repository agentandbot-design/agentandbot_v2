defmodule AgentbotCore.Modules.Chat.RoomTest do
  @moduledoc """
  Room schema testleri — DB entegrasyonlu.

  Anti-Crash Manifesto: Kara kutu kod yok. Schema contract'ları test edilmeli.
  """

  use AgentbotCore.Test.DataCase, async: true

  alias AgentbotCore.Modules.Chat.Room

  describe "changeset/2" do
    test "geçerli attributelerle changeset geçerli" do
      changeset = Room.changeset(%Room{}, %{name: "Test Odası", description: "Açıklama"})
      assert changeset.valid?
    end

    test "isim olmadan geçersiz" do
      changeset = Room.changeset(%Room{}, %{description: "Açıklama"})
      refute changeset.valid?
    end

    test "boş isim geçersiz" do
      changeset = Room.changeset(%Room{}, %{name: ""})
      refute changeset.valid?
    end

    test "100 karakterden uzun isim geçersiz" do
      changeset = Room.changeset(%Room{}, %{name: String.duplicate("x", 101)})
      refute changeset.valid?
    end

    test "default değerler doğru" do
      changeset = Room.changeset(%Room{}, %{name: "Oda"})
      room = Ecto.Changeset.apply_changes(changeset)

      assert room.room_type == "general"
      assert room.max_agents == 50
      assert room.is_active == true
    end
  end

  describe "create/1 ve list_active/0" do
    test "oda oluşturur ve listeler" do
      {:ok, room} = Room.create(%{name: "Genel", description: "Test"})

      assert room.id != nil
      assert room.name == "Genel"

      rooms = Room.list_active()
      assert rooms != []
      assert room.id in Enum.map(rooms, & &1.id)
    end

    test "is_active false olan oda listelenmez" do
      {:ok, room} = Room.create(%{name: "Pasif Oda", is_active: false})
      rooms = Room.list_active()

      refute room.id in Enum.map(rooms, & &1.id)
    end
  end

  describe "Jason serialization" do
    test "Room struct JSON'a serialize edilir" do
      {:ok, room} = Room.create(%{name: "JSON Test"})

      json = Jason.encode!(room)
      decoded = Jason.decode!(json)

      assert decoded["name"] == "JSON Test"
      assert decoded["room_type"] == "general"
      # __meta__ ve association field'ları gelmez
      refute Map.has_key?(decoded, "__meta__")
    end
  end
end
