# Passagem — Pessoa 01 para Pessoa 02 / v0.2

Receba a pasta inteira. A base oferece apelidos, criação de salas públicas e
privadas, entrada por chave e mensagens isoladas por tópico. Confira a execução
com um nó antes de integrar o cluster. As telas usam o protocolo de PROTOCOLO.md.

## Pontos de integração

1. Configurar nomes BEAM únicos, cookie de distribuição e descoberta de nós.
   Cada nó deve alcançar os outros por rede e pelas portas de distribuição.
   `NODE_LABEL` altera a exibição, mas não conecta uma VM ao cluster.
2. Substituir o catálogo local. Implemente o behaviour `Rooms.Store` e configure
   `:room_store` em `config/config.exs`. `Application` já inicia o child_spec do
   adaptador selecionado. Preserve os retornos documentados do contrato.
3. Compartilhar IDs, tipos e hashes de chaves entre os nós. Uma sala criada no
   nó A precisa ser localizada e autorizada no B. Conectar PubSub sem resolver
   o catálogo permite mensagens, mas deixa as salas criadas desconhecidas nos
   demais nós. Não há catálogo distribuído implementado nesta entrega.
4. Manter o nome lógico `ChatDistribuido.PubSub` e os tópicos. Ao conectar os
   nós, verificar o broadcast da conversa e os avisos do catálogo público.
5. Implementar Presence em componente próprio e acrescentar seus eventos à
   interface. Uma lista de usuários online não substitui o catálogo de salas.
6. Preparar a entrada de novos nós. O balanceador precisa encaminhar novas
   conexões aos nós disponíveis. Um WebSocket existente permanece ligado ao
   seu servidor; redirecionamento depende de reconexão, não de migração automática.
7. Atualizar somente o necessário no transporte; a interface usa `/socket`,
   relativo ao host que forneceu a página. Nenhum IP deve ficar gravado nela.

## Contrato do catálogo

O adaptador implementa:

| Função | Retorno |
|---|---|
| `child_spec(opts)` | Especificação supervisionada do serviço |
| `create(room)` | `{:ok, room}` ou `{:error, motivo}` |
| `fetch(id)` | `{:ok, room}` ou `{:error, motivo}` |
| `public_rooms()` | Lista de mapas internos de salas públicas |
| `find_by_key(hash)` | `{:ok, room}` ou `{:error, motivo}` |

O mapa interno tem `id`, `nome`, `tipo`, `criado_por`, `criado_em` e `key_hash`.
`key_hash` é nil em sala pública ou um SHA-256 binário de 32 bytes na privada.
A fachada `Rooms` gera IDs e chaves, normaliza a chave e filtra a representação
pública. Os Channels não precisam conhecer o mecanismo de armazenamento.

`LocalStore` usa leituras concorrentes em ETS e serializa apenas criações.
Mensagens não entram nesse processo: cada Channel recebe o texto e publica no
PubSub. Preserve essa separação para evitar concentrar mensagens em um catálogo.

## Bancada de 15 cópias

```console
docker compose -p sd15 -f compose.15.yml up --build --scale chat=15 -d
docker compose -p sd15 -f compose.15.yml ps
docker compose -p sd15 -f compose.15.yml port --index 1 chat 4000
```

O arquivo atual publica uma porta aleatória por container e usa até dois
schedulers BEAM por processo. As 15 cópias começam independentes. Adapte a rede,
o comando de inicialização e a descoberta para torná-las nós nomeados e
conectados; então integre o adaptador de catálogo. Depois valide salas públicas
entre nós, entrada privada por chave e isolamento de salas diferentes.

Uma rede Compose em um computador não conecta automaticamente containers de
outro. Para testes entre máquinas, configure nomes alcançáveis e portas.

## Como aumentar capacidade

Para o protótipo, a primeira demonstração pode ampliar manualmente o número de
nós. Uma automação posterior pode observar conexões, CPU ou filas, pedir mais
instâncias ao ambiente, aguardar sua saúde e incluí-las no encaminhamento. Essa
automação não está embutida em Elixir ou no catálogo da Pessoa 01.

A disponibilidade de mais recursos precisa ser medida. Quinze instâncias são
uma meta de bancada, não uma afirmação de capacidade ou tolerância a falhas.
A carga curta de `scripts/carga.mjs` usa 15 clientes por padrão, que é uma
contagem diferente da quantidade de servidores.

## Passagem para Pessoas 03 e 04

Entregar o projeto integrado, configurações externas e protocolo atualizado.
Pessoa 03 amplia infraestrutura, balanceador e demonstração de falhas. Pessoa
04 amplia carga e métricas, registrando o que o ambiente realmente sustenta.
