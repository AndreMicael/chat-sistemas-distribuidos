defmodule ChatDistribuidoWeb.RoomChannelTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest
  @endpoint ChatDistribuidoWeb.Endpoint

  defp entrar(usuario) do
    socket(ChatDistribuidoWeb.UserSocket, "teste-#{usuario}", %{})
    |> subscribe_and_join(ChatDistribuidoWeb.RoomChannel, "room:geral", %{"usuario" => usuario})
  end

  test "mensagem chega ao tópico e usa o apelido registrado ao entrar" do
    assert {:ok, %{usuario: "Ana"}, socket} = entrar("Ana")
    ref = push(socket, "new_msg", %{"texto" => "Olá", "usuario" => "Outro"})
    assert_reply(ref, :ok, %{id: id})
    assert_broadcast("new_msg", %{id: ^id, texto: "Olá", usuario: "Ana"})
  end

  test "rejeita mensagem inválida sem encerrar o canal" do
    {:ok, _, socket} = entrar("Ana")
    ref = push(socket, "new_msg", %{"texto" => "   "})
    assert_reply(ref, :error, %{reason: _})
    refute_broadcast("new_msg", _)

    ref = push(socket, "new_msg", %{"texto" => "Agora válida"})
    assert_reply(ref, :ok, _)
  end

  test "rejeita entrada sem apelido e sala inexistente" do
    socket = socket(ChatDistribuidoWeb.UserSocket, "teste", %{})

    assert {:error, %{reason: _}} =
             subscribe_and_join(socket, ChatDistribuidoWeb.RoomChannel, "room:geral", %{})

    assert {:error, %{reason: _}} =
             subscribe_and_join(socket, ChatDistribuidoWeb.RoomChannel, "room:outra", %{
               "usuario" => "Ana"
             })
  end
end
