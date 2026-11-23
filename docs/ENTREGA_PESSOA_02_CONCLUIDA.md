# Entrega Concluída — Pessoa 02: Clusterização e Estado Distribuído

Esta etapa expande o protótipo da Pessoa 01 para um **cluster distribuído real de nós BEAM** com **presença em tempo real via CRDTs** e **catálogo de salas replicado entre nós**.

---

## 1. O Que Foi Implementado

### A. Presença de Usuários em Tempo Real com CRDTs (`Phoenix.Presence`)
- **Módulo**: `ChatDistribuidoWeb.Presence` (`lib/chat_distribuido_web/channels/presence.ex`).
- **Como funciona**: Usa CRDTs (*Conflict-free Replicated Data Types*) nativos do Phoenix/Erlang.
- Quando um usuário entra em qualquer sala em qualquer nó do cluster, o `RoomChannel` rastreia o participante via `Presence.track/3`.
- O estado de presença (`presence_state` e `presence_diff`) é sincronizado automaticamente entre todos os servidores sem necessidade de travas (locks) ou banco de dados centralizado.
- **Interface Web**: Exibe um badge de status com contador em tempo real (`X online`) e chips identificando cada usuário e o nó exato onde sua conexão WebSocket está hospedada (`[● Ana (chat1@chat-1)]`).

### B. Catálogo de Salas Distribuído e Replicado (`DistributedStore`)
- **Módulo**: `ChatDistribuido.Rooms.DistributedStore` (`lib/chat_distribuido/rooms/distributed_store.ex`).
- Substitui o antigo `LocalStore` como o adaptador configurado em `config/config.exs`.
- **Leituras Locais de Alta Concorrência**: Tabelas `:ets` em memória com `read_concurrency: true` em cada nó.
- **Escritas e Replicações**:
  - Ao criar uma sala pública ou privada em qualquer nó, um evento assíncrono é transmitido via `Phoenix.PubSub` no tópico interno `"catalog:cluster_sync"`.
  - Todos os demais nós do cluster recebem o evento, adicionam a sala às suas tabelas ETS locais e notificam os clientes conectados.
  - Salas privadas e seus hashes SHA-256 (`key_hash`) são sincronizados entre os nós, permitindo que convidados entrem por chave em qualquer servidor do cluster.
- **Sincronização de Estado (Anti-Entropy / Full Dump)**:
  - Ao iniciar ou reconectar um nó, ele envia `{:request_sync, Node.self()}` aos nós vizinhos e recebe o catálogo completo de salas existentes.

### C. Descoberta e Formação Automática do Cluster BEAM (`Cluster.Discovery`)
- **Módulo**: `ChatDistribuido.Cluster.Discovery` (`lib/chat_distribuido/cluster/discovery.ex`).
- Gerencia a conexão nativa entre nós Erlang/Elixir (`Node.connect/1`).
- Monitora conexões e desconexões via `:net_kernel.monitor_nodes(true)` e tenta reconectar nós periodicamente conforme a variável de ambiente `CLUSTER_NODES`.
- Suporte dinâmico a inicialização de nomes de nós BEAM (`NODE_NAME`) e cookies compartilhados (`COOKIE`).
- Status detalhado do cluster exposto no endpoint de saúde `/health`.

---

## 2. Como Rodar o Cluster de 3 Nós

Para a demonstração ou desenvolvimento, utilize o arquivo `compose.cluster.yml`:

```console
docker compose -f compose.cluster.yml up --build
```

Isso inicializa 3 instâncias conectadas em cluster na mesma rede Docker:
- **Nó 1**: [http://localhost:4001](http://localhost:4001) (`chat1@chat-1`)
- **Nó 2**: [http://localhost:4002](http://localhost:4002) (`chat2@chat-2`)
- **Nó 3**: [http://localhost:4003](http://localhost:4003) (`chat3@chat-3`)

Para parar: `Ctrl+C` ou `docker compose -f compose.cluster.yml down`.

---

## 3. Roteiro de Demonstração para a Apresentação (10 Minutos)

Para a fala da **Pessoa 02** (tempo sugerido: 2m30s):

1. **Abra duas janelas do navegador lado a lado**:
   - Janela 1: [http://localhost:4001](http://localhost:4001) (Conectado ao Nó 1). Entre com o apelido **Ana**.
   - Janela 2: [http://localhost:4002](http://localhost:4002) (Conectado ao Nó 2). Entre com o apelido **Bruno**.
2. **Demonstre o Phoenix.Presence com CRDTs**:
   - Ambas as janelas entrarão na sala **Geral**.
   - Aponte para a barra "Online agora (CRDT)" no topo do chat:
     - Na janela da Ana: aparece **Ana (chat1@chat-1)** e **Bruno (chat2@chat-2)**.
     - Na janela do Bruno: aparece exatamente a mesma lista sincronizada.
   - Destaque: *"Mesmo estando conectados a servidores e portas completamente diferentes, a presença é sincronizada em tempo real via CRDTs, sem nenhum banco centralizado!"*
3. **Demonstre a Troca de Mensagens Distribuída**:
   - A Ana envia uma mensagem no Nó 1.
   - O Bruno recebe instantaneamente no Nó 2 com o carimbo `via chat1@chat-1`.
   - Explique: *"O Phoenix.PubSub distribui as mensagens entre os nós BEAM usando grupos de processos Erlang (:pg) nativos."*
4. **Demonstre o Catálogo Distribuído (Salas Públicas e Privadas)**:
   - Na janela da Ana (Nó 1), crie uma sala privada chamada **Projeto SD** e copie a chave gerada.
   - No Nó 1 a sala não é pública. Na janela do Bruno (Nó 2), clique em **Entrar com chave** e cole a chave.
   - O Bruno entra com sucesso na sala criada no outro servidor, e a lista de presença CRDT daquela sala atualiza para ambos!
5. **Demonstre Tolerância a Falhas (Chaos Test para Pessoas 03 e 04)**:
   - Em um terminal, execute:
     ```console
     docker stop chat-2
     ```
   - O Nó 2 cai. Observe os logs do Nó 1 e Nó 3 registrando o evento `:nodedown`.
   - Na janela da Ana (Nó 1), o Bruno é removido automaticamente da lista de presença via evento `presence_diff` do CRDT.
   - Ao religar o container (`docker start chat-2`), o nó se reconecta ao cluster, solicita o dump de salas e volta a operar normalmente!
