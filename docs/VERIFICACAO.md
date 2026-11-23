# Verificação desta entrega — 13/11/2026

## Executado com sucesso

- Compilação do projeto no ambiente `prod`, com avisos tratados como erro.
- Seis testes ExUnit: validação de dados, contrato de mensagem, entrada na sala,
  publicação no tópico, rejeição de entradas inválidas e rotas HTTP.
- Verificação de formatação do código Elixir.
- Cópia somente do código-fonte para outra pasta, cujo nome contém espaços,
  recuperação das dependências fixadas e recompilação sem copiar `deps/` ou `_build/`.
- Inicialização da cópia com outra porta e identificação de servidor configurada
  por variável de ambiente; resposta correta do endpoint `/health`.
- Carregamento dos módulos JavaScript servidos pelo projeto em DOM simulado
  (JSDOM), com o cliente oficial Phoenix e conexões WebSocket reais ao servidor.
- Dois clientes com hosts de acesso diferentes (`localhost` e `127.0.0.1`), troca
  de mensagens nos dois sentidos e uma única exibição por mensagem em cada cliente.
- Texto semelhante a HTML exibido literalmente, sem criação de elementos HTML.
- Rejeição de WebSocket com origem externa à página do chat.
- Detecção da interrupção do servidor, reconexão automática após reinício e nova
  troca de mensagens.
- Saída explícita da sala retornando ao formulário de identificação.
- Validação sintática do JavaScript e leitura do YAML do Compose.

Runtime de teste: Elixir 1.20.5 e Erlang/OTP 27 em Linux.

## Limites da verificação

Docker não estava disponível no ambiente de criação. Portanto, a imagem não foi
montada e o fluxo completo `docker compose up --build` precisa ser confirmado
no computador do integrante. Dockerfile, configuração e comandos foram revisados.

A abertura de Chromium foi impedida pelo ambiente de teste. O teste do cliente
usou DOM simulado e WebSockets reais; não constitui validação visual em navegador.
A aparência em desktop/mobile e a execução em Windows/macOS devem ser conferidas
pelos integrantes. Não foram simulados dois computadores físicos nem medida carga.

## Aceite no computador de quem recebe

1. Extrair o projeto e executar os passos do README.
2. Confirmar `/health` e duas abas trocando mensagens.
3. Repetir o procedimento em outro computador com os requisitos instalados.
4. Entregar o projeto completo à Pessoa 02, preservando `mix.lock` e o contrato.

## Correção após teste do integrante — 15/11/2026

A primeira montagem no CachyOS baixou a imagem oficial, mas falhou ao executar
`mix local.hex`: `:pubkey_os_cacerts` não encontrou certificados CA no sistema
da imagem slim (`:no_cacerts_found`). O Dockerfile foi corrigido para instalar
`ca-certificates` e atualizar o conjunto de certificados antes de chamar Mix.

Foi conferida a ordem das instruções no Dockerfile e a integridade do ZIP
atualizado. A montagem completa com Docker permanece pendente de confirmação
no computador do integrante; essa correção não altera as regras do chat.
