defmodule ChatDistribuido.RoomsTest do
  use ExUnit.Case, async: false
  alias ChatDistribuido.Rooms

  test "salas públicas são listadas; privadas e suas chaves não vazam para o catálogo" do
    assert {:ok, %{sala: public, chave: nil}} =
             Rooms.create(%{"nome" => "Tecnologia", "tipo" => "publica"}, "Ana")

    assert {:ok, %{sala: private, chave: key}} =
             Rooms.create(%{"nome" => "Trabalho", "tipo" => "privada"}, "Ana")

    ids = Enum.map(Rooms.list_public(), & &1.id)
    assert public.id in ids
    refute private.id in ids
    refute Map.has_key?(private, :key_hash)
    refute Map.has_key?(private, :chave)
    assert {:ok, ^public} = Rooms.authorize(public.id)
    assert {:error, _} = Rooms.authorize(private.id)
    assert {:error, _} = Rooms.authorize(private.id, "ERRADA")
    assert {:ok, ^private} = Rooms.authorize(private.id, String.downcase(key))
    assert {:ok, ^private} = Rooms.find_private(" " <> key <> " ")
  end

  test "validação não cria sala nem converte entrada do usuário em átomos" do
    for params <- [
          %{"nome" => "", "tipo" => "publica"},
          %{"nome" => String.duplicate("x", 61), "tipo" => "publica"},
          %{"nome" => "Sala", "tipo" => "outro"},
          %{"nome" => 123, "tipo" => "privada"}
        ] do
      assert {:error, _} = Rooms.create(params, "Ana")
    end

    assert {:error, _} = Rooms.find_private(nil)
    assert {:error, _} = Rooms.authorize("inexistente")
  end

  test "criações concorrentes têm identificadores e chaves independentes" do
    results =
      1..30
      |> Task.async_stream(
        fn i ->
          Rooms.create(%{"nome" => "Sala #{i}", "tipo" => "privada"}, "Ana")
        end,
        max_concurrency: 15
      )
      |> Enum.map(fn {:ok, {:ok, result}} -> result end)

    assert length(Enum.uniq_by(results, & &1.sala.id)) == 30
    assert length(Enum.uniq_by(results, & &1.chave)) == 30
  end
end
