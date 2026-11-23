defmodule ChatDistribuidoWeb.Presence do
  @moduledoc """
  Presença de usuários em tempo real utilizando CRDTs (Conflict-free Replicated Data Types).
  Sincroniza automaticamente a lista de participantes entre todos os nós do cluster sem lock central.
  """
  use Phoenix.Presence,
    otp_app: :chat_distribuido,
    pubsub_server: ChatDistribuido.PubSub
end
