import Config

config :chat_distribuido, :room_store, ChatDistribuido.Rooms.DistributedStore

config :chat_distribuido, ChatDistribuidoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: ChatDistribuido.PubSub,
  check_origin: :conn,
  render_errors: [formats: [json: ChatDistribuidoWeb.ErrorJSON], layout: false],
  code_reloader: false,
  debug_errors: false

config :phoenix, :json_library, Jason
config :logger, :console, format: "$time [$level] $message\n"
config :logger, level: :info

if config_env() == :test do
  config :logger, level: :warning
end
