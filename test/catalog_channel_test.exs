defmodule ChatDistribuidoWeb.CatalogChannelTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest
  alias ChatDistribuido.Rooms
  @endpoint ChatDistribuidoWeb.Endpoint

  test "catálogo exige apelido e mantém as salas privadas fora dos eventos públicos" do
    socket = socket(ChatDistribuidoWeb.UserSocket, "catalog-test", %{})

    assert {:error, _} =
             subscribe_and_join(socket, ChatDistribuidoWeb.CatalogChannel, "catalog:rooms", %{})

    {:ok, %{salas: salas}, socket} =
      subscribe_and_join(socket, ChatDistribuidoWeb.CatalogChannel, "catalog:rooms", %{
        "usuario" => "Ana"
      })

    assert Enum.any?(salas, &(&1.id == "geral"))
    ref = push(socket, "create_room", %{"nome" => "Restrita", "tipo" => "privada"})
    assert_reply(ref, :ok, %{sala: private, chave: key})
    refute_push("public_rooms", _)
    ref = push(socket, "find_private", %{"chave" => "ERRADA"})
    assert_reply(ref, :error, _)
    ref = push(socket, "find_private", %{"chave" => key})
    assert_reply(ref, :ok, %{sala: ^private})
    ref = push(socket, "create_room", %{"nome" => "Pública", "tipo" => "publica"})
    assert_reply(ref, :ok, %{sala: public})
    assert_push("public_rooms", %{salas: listed})
    assert Enum.any?(listed, &(&1.id == public.id))
    refute Enum.any?(listed, &(&1.id == private.id))
  end

  test "entrada privada é validada antes da assinatura do tópico" do
    {:ok, %{sala: room, chave: key}} =
      Rooms.create(%{"nome" => "Privada", "tipo" => "privada"}, "Ana")

    socket = socket(ChatDistribuidoWeb.UserSocket, "room-test", %{})

    assert {:error, _} =
             subscribe_and_join(socket, ChatDistribuidoWeb.RoomChannel, "room:" <> room.id, %{
               "usuario" => "Bruno"
             })

    assert {:error, _} =
             subscribe_and_join(socket, ChatDistribuidoWeb.RoomChannel, "room:" <> room.id, %{
               "usuario" => "Bruno",
               "chave" => "errada"
             })

    {:ok, _, joined} =
      subscribe_and_join(socket, ChatDistribuidoWeb.RoomChannel, "room:" <> room.id, %{
        "usuario" => "Bruno",
        "chave" => key
      })

    ref = push(joined, "new_msg", %{"texto" => "Privada"})
    assert_reply(ref, :ok, _)
    assert_broadcast("new_msg", %{sala_id: id, usuario: "Bruno"})
    assert id == room.id
  end
end
