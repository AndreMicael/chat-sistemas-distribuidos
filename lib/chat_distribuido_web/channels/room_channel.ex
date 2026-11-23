defmodule ChatDistribuidoWeb.RoomChannel do
  @moduledoc "Adapta eventos WebSocket às regras do chat e presença CRDT. Contrato em docs/PROTOCOLO.md."
  use Phoenix.Channel
  alias ChatDistribuido.{Chat, NodeInfo, Rooms}
  alias ChatDistribuidoWeb.Presence

  @impl true
  def join("room:" <> id, %{"usuario" => usuario} = params, socket) do
    with {:ok, usuario} <- Chat.validar_usuario(usuario),
         {:ok, room} <- Rooms.authorize(id, params["chave"]) do
      send(self(), :after_join)

      {:ok, %{usuario: usuario, sala: room, no: NodeInfo.nome()},
       socket |> assign(:usuario, usuario) |> assign(:sala_id, id)}
    else
      {:error, reason} -> {:error, %{reason: reason}}
    end
  end

  def join("room:" <> _, _, _), do: {:error, %{reason: "Informe um apelido para entrar."}}
  def join(_, _, _), do: {:error, %{reason: "Sala inválida."}}

  @impl true
  def handle_in("new_msg", %{"texto" => texto}, socket) do
    case Chat.criar_mensagem(socket.assigns.usuario, texto, NodeInfo.nome()) do
      {:ok, message} ->
        message = Map.put(message, :sala_id, socket.assigns.sala_id)
        broadcast!(socket, "new_msg", message)
        {:reply, {:ok, %{id: message.id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("new_msg", _payload, socket) do
    {:reply, {:error, %{reason: "Envie uma mensagem com o campo texto."}}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "Evento desconhecido."}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.usuario, %{
        online_at: System.system_time(:second),
        no: NodeInfo.nome()
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
