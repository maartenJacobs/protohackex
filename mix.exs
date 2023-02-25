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
      test: ["test --no-start --exclude integration"],
      # Run the integration tests with `MIX_ENV=dev mix integration`.
      # TODO: improve `Tcp` so I can run this along with `mix test`.
      integration: ["test --only integration"]
    ]
  end
end
