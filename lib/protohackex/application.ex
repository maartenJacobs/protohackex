defmodule Protohackex.Application do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:protohackex, :port)

    children = [
      {Registry, keys: :unique, name: Protohackex.NeedForLessSpeed.Heart.Registry},
      Protohackex.NeedForLessSpeed.Heart,
      Protohackex.NeedForLessSpeed.Client.Supervisor,
      Protohackex.NeedForLessSpeed.Dispatch,
      Protohackex.NeedForLessSpeed.RoadRegistry,
      Tcp.AsyncServer.ConnectionSupervisor,
      {Tcp.AsyncServer,
       [port: port, handler_mod: Protohackex.NeedForLessSpeed.Client.Unidentified]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
