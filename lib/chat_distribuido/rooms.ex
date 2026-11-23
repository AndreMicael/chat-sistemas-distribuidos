defmodule ChatDistribuido.Rooms do
  @moduledoc "Fachada do catálogo. Channels e clientes não conhecem o armazenamento."
  alias ChatDistribuido.Rooms.{Room, Store}
  def list_public, do: Enum.map(Store.public_rooms(), &Room.view/1)

  def create(params, creator) do
    with {:ok, room, key} <- Room.new(params, creator),
         {:ok, room} <- Store.create(room) do
      if room.tipo == "publica" do
        Phoenix.PubSub.broadcast(ChatDistribuido.PubSub, "catalog:rooms", :public_rooms_changed)
      end

      {:ok, %{sala: Room.view(room), chave: key}}
    end
  end

  def authorize(id, key \\ nil) do
    with {:ok, room} <- Store.fetch(id),
         :ok <- Room.authorize(room, key),
         do: {:ok, Room.view(room)}
  end

  def find_private(key) when is_binary(key) and byte_size(key) <= 64 do
    with {:ok, room} <- Store.find_by_key(Room.key_hash(key)),
         do: {:ok, Room.view(room)}
  end

  def find_private(_), do: {:error, "Informe uma chave de entrada válida."}
end
