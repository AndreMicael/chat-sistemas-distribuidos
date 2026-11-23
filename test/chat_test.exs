defmodule ChatDistribuido.ChatTest do
  use ExUnit.Case, async: true
  alias ChatDistribuido.Chat

  test "normaliza apelido e texto, mantendo os campos do protocolo" do
    assert {:ok, msg} = Chat.criar_mensagem(" Ana ", " Olá! ", "teste")
    assert msg.usuario == "Ana"
    assert msg.texto == "Olá!"
    assert msg.no == "teste"
    assert {:ok, _, _} = DateTime.from_iso8601(msg.enviado_em)
    assert byte_size(msg.id) > 0
  end

  test "rejeita dados vazios, tipos incorretos e texto acima do limite" do
    for value <- [nil, 123, "", "   ", String.duplicate("á", 25)] do
      assert {:error, _} = Chat.validar_usuario(value)
    end

    for value <- [nil, [], "", " \n ", String.duplicate("a", 501)] do
      assert {:error, _} = Chat.criar_mensagem("Ana", value, "teste")
    end

    assert {:ok, _} = Chat.criar_mensagem("Ana", String.duplicate("á", 500), "teste")
  end
end
