defmodule ChatDistribuido.Rooms.DistributedStore do
  @moduledoc """
  Repositório de salas distribuído e replicado entre nós BEAM.
  - Leituras ultra-rápidas em tabelas ETS locais (concorrência total).
  - Escritas replicadas em broadcast assíncrono pelo Phoenix.PubSub.
  - Sincronização automática de estado (anti-entropy / full dump) quando novos nós entram no cluster.
  """
  use GenServer
  require Logger
  @behaviour ChatDistribuido.Rooms.Store
  alias ChatDistribuido.Rooms.Room

  @rooms :chat_distribuido_dist_rooms
  @keys :chat_distribuido_dist_room_keys
  @max_rooms 10_000
  @sync_topic "catalog:cluster_sync"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def create(room), do: GenServer.call(__MODULE__, {:create, room})

  @impl true
  def fetch(id) do
    case :ets.lookup(@rooms, id) do
      [{^id, room}] -> {:ok, room}
      [] -> {:error, "Sala não encontrada neste servidor ou cluster."}
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
      [] -> {:error, "Chave inválida ou sala indisponível neste servidor ou cluster."}
    end
  end

  # Callbacks GenServer

  @impl true
  def init(_) do
    :ets.new(@rooms, [:named_table, :protected, :set, read_concurrency: true])
    :ets.new(@keys, [:named_table, :protected, :set, read_concurrency: true])

    # Sala Geral sempre existe por padrão
    room = Room.general()
    :ets.insert(@rooms, {room.id, room})

    # Assina tópico de replicação e monitora nós
    Phoenix.PubSub.subscribe(ChatDistribuido.PubSub, @sync_topic)
    :net_kernel.monitor_nodes(true)

    # Se já houver outros nós, solicita sincronização do catálogo
    if Node.alive?() and Node.list() != [] do
      send(self(), :request_sync_now)
    end

    {:ok, %{synced_from: nil}}
  end

  @impl true
  def handle_call({:create, room}, _from, state) do
    cond do
      :ets.info(@rooms, :size) >= @max_rooms ->
        {:reply, {:error, "Limite de salas do cluster atingido."}, state}

      :ets.member(@rooms, room.id) or
          (room.key_hash != nil and :ets.member(@keys, room.key_hash)) ->
        {:reply, {:error, "Identificação repetida. Tente criar a sala novamente."}, state}

      true ->
        insert_room(room)

        # Broadcast da nova sala para todos os outros nós do cluster
        Phoenix.PubSub.broadcast(
          ChatDistribuido.PubSub,
          @sync_topic,
          {:replicate_room, room, Node.self()}
        )

        {:reply, {:ok, room}, state}
    end
  end

  @impl true
  def handle_info(:request_sync_now, state) do
    Phoenix.PubSub.broadcast(
      ChatDistribuido.PubSub,
      @sync_topic,
      {:request_sync, Node.self()}
    )
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("[DistributedStore] Nó conectado: #{inspect(node)}. Solicitando sincronização de salas.")
    Phoenix.PubSub.broadcast(
      ChatDistribuido.PubSub,
      @sync_topic,
      {:request_sync, Node.self()}
    )
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("[DistributedStore] Nó desconectado: #{inspect(node)}.")
    {:noreply, state}
  end

  @impl true
  def handle_info({:replicate_room, room, origin_node}, state) do
    if origin_node != Node.self() do
      Logger.debug("[DistributedStore] Replicando sala #{room.id} (#{room.nome}) recebida de #{inspect(origin_node)}.")
      insert_room(room)

      if room.tipo == "publica" do
        Phoenix.PubSub.broadcast(ChatDistribuido.PubSub, "catalog:rooms", :public_rooms_changed)
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:request_sync, requester_node}, state) do
    if requester_node != Node.self() do
      all_rooms =
        :ets.tab2list(@rooms)
        |> Enum.map(fn {_, room} -> room end)

      Logger.info("[DistributedStore] Enviando catálogo com #{length(all_rooms)} sala(s) para #{inspect(requester_node)}.")

      Phoenix.PubSub.broadcast(
        ChatDistribuido.PubSub,
        @sync_topic,
        {:sync_dump, all_rooms, requester_node}
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:sync_dump, rooms, target_node}, state) do
    if target_node == Node.self() do
      Logger.info("[DistributedStore] Recebido dump de catálogo com #{length(rooms)} sala(s). Atualizando ETS local.")
      Enum.each(rooms, &insert_room/1)
      Phoenix.PubSub.broadcast(ChatDistribuido.PubSub, "catalog:rooms", :public_rooms_changed)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_other, state), do: {:noreply, state}

  defp insert_room(room) do
    :ets.insert(@rooms, {room.id, room})
    if room.key_hash, do: :ets.insert(@keys, {room.key_hash, room.id})
    :ok
  end
end
