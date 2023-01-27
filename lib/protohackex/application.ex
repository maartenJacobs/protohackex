defmodule Protohackex.Application do
  use Application

  def start(_type, _args) do
    _port = Application.get_env(:protohackex, :port)

    children = [
      # {server, [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
