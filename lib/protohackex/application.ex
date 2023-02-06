defmodule Protohackex.Application do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:protohackex, :port)

    children = [
      {Protohackex.ChatServer, [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
