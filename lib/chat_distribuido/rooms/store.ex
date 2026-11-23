defmodule ChatDistribuido.Rooms.Store do
  @moduledoc """
  Contrato do catálogo. A Pessoa 02 implementa este behaviour e muda :room_store.
  Este componente guarda metadados de salas; nunca recebe mensagens do chat.
  """
  @callback child_spec(keyword()) :: Supervisor.child_spec()
  @callback create(map()) :: {:ok, map()} | {:error, String.t()}
  @callback fetch(String.t()) :: {:ok, map()} | {:error, String.t()}
  @callback public_rooms() :: [map()]
  @callback find_by_key(binary()) :: {:ok, map()} | {:error, String.t()}

  def adapter, do: Application.fetch_env!(:chat_distribuido, :room_store)
  def child_spec, do: adapter().child_spec([])
  def create(room), do: adapter().create(room)
  def fetch(id), do: adapter().fetch(id)
  def public_rooms, do: adapter().public_rooms()
  def find_by_key(hash), do: adapter().find_by_key(hash)
end
