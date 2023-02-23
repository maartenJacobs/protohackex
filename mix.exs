defmodule Protohackex.MixProject do
  use Mix.Project

  def project do
    [
      app: :protohackex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Protohackex.Application, []},
      env: [port: 8080],
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases() do
    [
      up: ["deps.get", "compile", "run --no-halt"],
      shell: ["deps.get", "compile", "run --no-start"],
      # `--no-start` is needed to avoid global registry
      test: ["test --no-start"]
    ]
  end
end
