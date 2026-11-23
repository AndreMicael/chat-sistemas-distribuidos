defmodule ChatDistribuido.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_distribuido,
      version: "0.2.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [setup: ["deps.get", "compile"]]
    ]
  end

  def application do
    [mod: {ChatDistribuido.Application, []}, extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.16"},
      {:bandit, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
