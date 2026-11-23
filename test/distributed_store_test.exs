defmodule ChatDistribuido.DistributedStoreTest do
  use ExUnit.Case, async: false
  alias ChatDistribuido.Rooms
  alias ChatDistribuido.Rooms.DistributedStore

  test "DistributedStore replica salas criadas via broadcast de sincronização" do
    sala_remota = %{
      id: "remota-123",
      nome: "Sala do Nó Remoto",
      tipo: "publica",
      criado_por: "OutroNó",
      criado_em: DateTime.utc_now() |> DateTime.to_iso8601(),
      key_hash: nil
    }

    send(DistributedStore, {:replicate_room, sala_remota, :outro_no@host})

    # Garante que o GenServer processou a mensagem antes da consulta
    _ = :sys.get_state(DistributedStore)

    assert {:ok, room} = DistributedStore.fetch("remota-123")
    assert room.nome == "Sala do Nó Remoto"
    assert room.id in Enum.map(DistributedStore.public_rooms(), & &1.id)
  end

  test "DistributedStore responde a pedidos de sincronização (request_sync)" do
    {:ok, %{sala: local}} = Rooms.create(%{"nome" => "Sala Local", "tipo" => "publica"}, "Ana")

    Phoenix.PubSub.subscribe(ChatDistribuido.PubSub, "catalog:cluster_sync")

    send(DistributedStore, {:request_sync, :novo_no@host})

    assert_receive {:sync_dump, rooms, :novo_no@host}, 1000
    assert Enum.any?(rooms, &(&1.id == local.id))
  end
end
