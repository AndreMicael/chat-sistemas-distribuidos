defmodule ChatDistribuidoWeb.CatalogChannel do
  @moduledoc "Operações de salas. Mensagens de conversa não passam por este Channel."
  use Phoenix.Channel
  alias ChatDistribuido.{Chat, Rooms, NodeInfo}
  @impl true
  def join("catalog:rooms", %{"usuario" => user}, socket) do
    with {:ok, user} <- Chat.validar_usuario(user) do
      {:ok, %{usuario: user, salas: Rooms.list_public(), no: NodeInfo.nome()},
       assign(socket, :usuario, user)}
    else
      {:error, reason} -> {:error, %{reason: reason}}
    end
  end

  def join(_, _, _), do: {:error, %{reason: "Informe um apelido para entrar."}}
  @impl true
  def handle_in("list_rooms", _, socket) do
    {:reply, {:ok, %{salas: Rooms.list_public()}}, socket}
  end

  def handle_in("create_room", params, socket) do
    build_reply(Rooms.create(params, socket.assigns.usuario), socket)
  end

  def handle_in("find_private", %{"chave" => key}, socket) do
    case Rooms.find_private(key) do
      {:ok, room} -> {:reply, {:ok, %{sala: room}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in(_, _, socket),
    do: {:reply, {:error, %{reason: "Evento ou dados inválidos."}}, socket}

  @impl true
  def handle_info(:public_rooms_changed, socket) do
    push(socket, "public_rooms", %{salas: Rooms.list_public()})
    {:noreply, socket}
  end

  defp build_reply({:ok, result}, socket), do: {:reply, {:ok, result}, socket}
  defp build_reply({:error, reason}, socket), do: {:reply, {:error, %{reason: reason}}, socket}
end
