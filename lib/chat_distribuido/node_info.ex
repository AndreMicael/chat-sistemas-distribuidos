defmodule ChatDistribuido.NodeInfo do
  @moduledoc "Identificação de exibição, preparada para nós BEAM nomeados na etapa 2."

  def nome do
    if Node.alive?() do
      Atom.to_string(Node.self())
    else
      Application.get_env(:chat_distribuido, :node_label, "local")
    end
  end
end
