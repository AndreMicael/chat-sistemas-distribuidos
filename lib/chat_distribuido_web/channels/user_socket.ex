defmodule ChatDistribuidoWeb.UserSocket do
  use Phoenix.Socket

  channel("room:*", ChatDistribuidoWeb.RoomChannel)
  channel("catalog:rooms", ChatDistribuidoWeb.CatalogChannel)

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
