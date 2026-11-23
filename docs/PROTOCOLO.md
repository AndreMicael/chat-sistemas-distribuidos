# Protocolo de integração — versão 2

Transporte Phoenix Channels, serializador JSON padrão, versão `2.0.0`.
Montagem `/socket`; WebSocket `/socket/websocket?vsn=2.0.0`.
Os frames são `[join_ref, ref, topic, event, payload]`. Um WebSocket pode carregar
um canal de catálogo e o canal da sala selecionada.

## Identificação e catálogo

Entrar em `catalog:rooms` com `{"usuario":"Ana"}`.
Resposta `ok`: `{"usuario":"Ana","salas":[...],"no":"nome-do-servidor"}`.
O apelido é normalizado e armazenado no socket do Channel. Apelidos repetidos
são permitidos neste protótipo.

| Evento enviado | Payload | Resposta ok |
|---|---|---|
| `list_rooms` | `{}` | `{"salas":[...]}` |
| `create_room` | `{"nome":"Tecnologia","tipo":"publica"}` | `{"sala":{...},"chave":null}` |
| `create_room` | `{"nome":"Trabalho","tipo":"privada"}` | `{"sala":{...},"chave":"ABCD2345"}` |
| `find_private` | `{"chave":"ABCD2345"}` | `{"sala":{...}}` |

Nome da sala: 1..60 caracteres após remover espaços nas pontas. Nome não é ID;
salas com o mesmo nome têm IDs distintos. Sala Geral tem ID estável `geral`.
Tipos válidos: `publica`, `privada`. Chaves são normalizadas para maiúsculas.
A chave é emitida na resposta de criação e não integra a representação pública.

Evento recebido `public_rooms`: `{"salas":[...]}`. Atualiza o catálogo após a
criação de uma sala pública. Salas privadas não entram nessa lista ou aviso.
Participantes conhecem uma privada ao criá-la ou localizar sua chave.

Representação da sala:

```json
{"id":"id-aleatorio","nome":"Tecnologia","tipo":"publica","criado_por":"Ana","criado_em":"2026-11-15T15:00:00Z"}
```

## Participação na sala

Entrar em `room:ID` com `{"usuario":"Ana"}` para pública e com
`{"usuario":"Ana","chave":"ABCD2345"}` para privada.
O servidor autoriza a entrada antes de assinar o tópico. Conhecer o ID de uma
privada não substitui a chave. Resposta `ok`:

```json
{"usuario":"Ana","sala":{"id":"geral","nome":"Geral","tipo":"publica","criado_por":"Sistema","criado_em":"2026-01-01T00:00:00Z"},"no":"nome-do-servidor"}
```

Evento de envio `new_msg`, payload `{"texto":"Olá!"}`. O apelido vem do join,
não do payload da mensagem. Texto: 1..500 caracteres após remover espaços nas
pontas. O servidor confirma `ok` com `{"id":"identificador-da-mensagem"}`.

Broadcast `new_msg`, incluindo o remetente, somente no tópico daquela sala:

```json
{"id":"identificador-da-mensagem","sala_id":"geral","usuario":"Ana","texto":"Olá!","enviado_em":"2026-11-15T15:00:00Z","no":"nome-do-servidor"}
```

O campo `sala_id` é novo em relação à primeira versão. O cliente exibe a
mensagem pelo broadcast; o ok do envio não cria outra cópia na conversa.

## Erros e saída

Eventos e joins inválidos recebem `error` com `{"reason":"motivo"}`. Isso
inclui chave ausente/incorreta, sala inexistente, texto ou apelido inválido.
Sair do canal da sala interrompe sua participação; o catálogo pode continuar
conectado. Ao encerrar a sessão, o cliente fecha o socket completo.

## Limites que a integração deve preservar ou substituir explicitamente

Não há replay, persistência, autenticação de conta ou ordem global garantida.
O ok confirma aceitação/publicação, não entrega a todos. Após reinício do
catálogo local, só Geral existe; os clientes devem escolher Geral ou criar
novamente suas salas. Ao integrar um catálogo compartilhado, mantenha IDs,
tipos e hashes consistentes para a reconexão em outros nós.

Presence terá eventos próprios, como `presence_state` e `presence_diff`, em
uma extensão da Pessoa 02. Não reutilizar `new_msg` para presença ou metadados.
