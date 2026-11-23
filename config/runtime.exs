import Config

# Endereço de escuta genérico; nenhum IP da máquina de desenvolvimento é gravado.
bind_ip = System.get_env("BIND_IP", "127.0.0.1")

ip =
  case :inet.parse_address(String.to_charlist(bind_ip)) do
    {:ok, address} -> address
    {:error, _} -> raise "BIND_IP deve ser um endereço IP válido."
  end

port =
  case Integer.parse(System.get_env("PORT", "4000")) do
    {value, ""} when value in 1..65_535 -> value
    _ -> raise "PORT deve ser um número entre 1 e 65535."
  end

# Esta etapa não usa sessões ou tokens persistentes. Sem configuração explícita,
# a chave é gerada a cada inicialização, sem segredo fixo no código-fonte.
secret = System.get_env("SECRET_KEY_BASE") || Base.encode64(:crypto.strong_rand_bytes(64))

if byte_size(secret) < 64 do
  raise "SECRET_KEY_BASE deve ter pelo menos 64 bytes."
end

label = System.get_env("NODE_LABEL")
label = if label in [nil, ""], do: System.get_env("HOSTNAME", "local"), else: label
config :chat_distribuido, :node_label, label

# Configuração de nó distribuído BEAM em runtime
node_name = System.get_env("NODE_NAME")
cookie = System.get_env("RELEASE_COOKIE") || System.get_env("COOKIE")

if node_name && node_name != "" && !Node.alive?() do
  type = if String.contains?(node_name, "."), do: :longnames, else: :shortnames

  case Node.start(String.to_atom(node_name), type) do
    {:ok, _} ->
      if cookie && cookie != "", do: Node.set_cookie(Node.self(), String.to_atom(cookie))

    {:error, reason} ->
      require Logger
      Logger.warning("Distribuição de nó não iniciada (#{inspect(reason)}). Operando em modo padrão.")
  end
end

if cookie && cookie != "" && Node.alive?() do
  Node.set_cookie(Node.self(), String.to_atom(cookie))
end

config :chat_distribuido, ChatDistribuidoWeb.Endpoint,
  http: [ip: ip, port: port],
  secret_key_base: secret,
  server: config_env() != :test
