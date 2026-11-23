defmodule ChatDistribuido.Rooms.LocalStore do
  @moduledoc """
  Adaptador local, temporário, para a Pessoa 01. Leituras concorrentes em ETS;
  criação serializada para atualizar índices. Não replica salas entre nós.
  """
  use GenServer
  @behaviour ChatDistribuido.Rooms.Store
  alias ChatDistribuido.Rooms.Room
  @rooms :chat_distribuido_rooms
  @keys :chat_distribuido_room_keys
  @max_rooms 2_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def create(room), do: GenServer.call(__MODULE__, {:create, room})
  @impl true
  def fetch(id) do
    case :ets.lookup(@rooms, id) do
      [{^id, room}] -> {:ok, room}
      [] -> {:error, "Sala não encontrada neste servidor."}
    end
  end

  @impl true
  def public_rooms do
    :ets.tab2list(@rooms)
    |> Enum.map(fn {_, room} -> room end)
    |> Enum.filter(&(&1.tipo == "publica"))
    |> Enum.sort_by(fn room -> {room.id != "geral", room.criado_em, room.id} end)
  end

  @impl true
  def find_by_key(hash) do
    case :ets.lookup(@keys, hash) do
      [{^hash, id}] -> fetch(id)
      [] -> {:error, "Chave inválida ou sala indisponível neste servidor."}
    end
  end

  @impl true
  def init(_) do
    :ets.new(@rooms, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@keys, [:named_table, :protected, :set, read_concurrency: true])
    room = Room.general()
    :ets.insert(@rooms, {room.id, room})
    {:ok, nil}
  end

  @impl true
  def handle_call({:create, room}, _, state) do
    cond do
      :ets.info(@rooms, :size) >= @max_rooms ->
        {:reply, {:error, "Limite de salas do protótipo atingido."}, state}

      :ets.member(@rooms, room.id) or
          (room.key_hash != nil and :ets.member(@keys, room.key_hash)) ->
        {:reply, {:error, "Identificação repetida. Tente criar a sala novamente."}, state}

      true ->
        :ets.insert(@rooms, {room.id, room})
        if room.key_hash, do: :ets.insert(@keys, {room.key_hash, room.id})
        {:reply, {:ok, room}, state}
    end
  end
end
