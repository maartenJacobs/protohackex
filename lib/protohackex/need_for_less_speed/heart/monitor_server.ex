defmodule Protohackex.NeedForLessSpeed.Heart.MonitorServer do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  defstruct [:socket, :name]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    server_options = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, socket, server_options)
  end

  # GenServer callbacks

  def init(socket) do
    Logger.info("Socket monitor started", socket: socket)
    :inet.monitor(socket)
    {:ok, %__MODULE__{socket: socket}}
  end

  def handle_info({:DOWN, _monitor_ref, _type, socket, _info}, %__MODULE__{} = state) do
    Logger.info("Socket monitor stopped", socket: socket)
    ^socket = state.socket
    {:stop, :normal, state}
  end
end
