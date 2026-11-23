defmodule ChatDistribuidoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chat_distribuido

  socket("/socket", ChatDistribuidoWeb.UserSocket,
    websocket: [max_frame_size: 8192],
    longpoll: false
  )

  # O cliente JavaScript vem da mesma versão de Phoenix fixada em mix.lock.
  # É servido pelo próprio projeto, sem CDN e sem instalação de Node.js.
  plug(Plug.Static,
    at: "/vendor",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.mjs)
  )

  plug(Plug.Static,
    at: "/",
    from: :chat_distribuido,
    only: ~w(css js)
  )

  plug(Plug.RequestId)
  plug(ChatDistribuidoWeb.Router)
end
