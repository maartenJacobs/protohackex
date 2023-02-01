defmodule Protohackex.Application do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:protohackex, :port)

    children = [
      Tcp.AsyncServer.ConnectionSupervisor,
      {Tcp.AsyncServer, [port: port, handler_mod: Protohackex.PrimeServer]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
