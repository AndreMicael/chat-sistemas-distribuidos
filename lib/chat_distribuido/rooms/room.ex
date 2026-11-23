defmodule ChatDistribuido.Rooms.Room do
  @moduledoc "Regras de sala e chave simples para o protótipo acadêmico."
  alias ChatDistribuido.Chat

  def new(%{"nome" => name, "tipo" => type}, creator) when type in ["publica", "privada"] do
    with {:ok, name} <- validate_name(name),
         {:ok, creator} <- Chat.validar_usuario(creator) do
      key = if type == "privada", do: Base.encode32(:crypto.strong_rand_bytes(5)), else: nil

      room = %{
        id: Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false),
        nome: name,
        tipo: type,
        criado_por: creator,
        criado_em: DateTime.utc_now() |> DateTime.to_iso8601(),
        key_hash: if(key, do: key_hash(key), else: nil)
      }

      {:ok, room, key}
    end
  end

  def new(_, _), do: {:error, "Informe nome e tipo de sala: publica ou privada."}

  def general do
    %{
      id: "geral",
      nome: "Geral",
      tipo: "publica",
      criado_por: "Sistema",
      criado_em: "2026-01-01T00:00:00Z",
      key_hash: nil
    }
  end

  def view(room), do: Map.take(room, [:id, :nome, :tipo, :criado_por, :criado_em])
  def authorize(%{tipo: "publica"}, _key), do: :ok

  def authorize(%{tipo: "privada", key_hash: expected}, key)
      when is_binary(key) and byte_size(key) <= 64 do
    if Plug.Crypto.secure_compare(key_hash(key), expected),
      do: :ok,
      else: {:error, "Chave de entrada inválida."}
  end

  def authorize(_, _), do: {:error, "Informe a chave de entrada desta sala."}
  def key_hash(key), do: :crypto.hash(:sha256, key |> String.trim() |> String.upcase())

  defp validate_name(name) when is_binary(name) do
    if String.valid?(name) and String.length(String.trim(name)) in 1..60,
      do: {:ok, String.trim(name)},
      else: {:error, "O nome da sala deve ter entre 1 e 60 caracteres."}
  end

  defp validate_name(_), do: {:error, "Informe um nome de sala válido."}
end
