defmodule ChatDistribuido.Chat do
  @moduledoc """
  Regras do chat, independentes de HTML, WebSocket e Docker.
  Não armazena histórico nem mantém uma lista local de usuários online.
  """

  @max_usuario 24
  @max_texto 500

  def validar_usuario(value) do
    validar_texto(value, @max_usuario, "O apelido deve ter entre 1 e 24 caracteres.")
  end

  def criar_mensagem(usuario, texto, no) do
    with {:ok, usuario} <- validar_usuario(usuario),
         {:ok, texto} <-
           validar_texto(texto, @max_texto, "A mensagem deve ter entre 1 e 500 caracteres.") do
      {:ok,
       %{
         id: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false),
         usuario: usuario,
         texto: texto,
         enviado_em: DateTime.utc_now() |> DateTime.to_iso8601(),
         no: no
       }}
    end
  end

  defp validar_texto(value, limit, reason) when is_binary(value) do
    if String.valid?(value) do
      text = String.trim(value)

      if String.length(text) in 1..limit do
        {:ok, text}
      else
        {:error, reason}
      end
    else
      {:error, reason}
    end
  end

  defp validar_texto(_value, _limit, reason), do: {:error, reason}
end
