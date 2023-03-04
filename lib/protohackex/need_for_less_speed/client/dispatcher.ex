defmodule Protohackex.NeedForLessSpeed.Client.Dispatcher do
  @moduledoc """
  Client connection to ticket sender responsible for multiple roads.
  """

  use GenServer, restart: :transient

  require Logger

  defstruct [:buffered_socket, :roads, :registry]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    roads = Keyword.fetch!(opts, :roads)
    registry = Keyword.get(opts, :registry, RoadRegistry)

    GenServer.start_link(__MODULE__, {socket, roads, registry})
  end

  # GenServer callbacks

  def init({buffered_socket, roads, registery}) do
    Logger.info("Dispatcher connected", socket: inspect(buffered_socket.socket))
    state = %__MODULE__{buffered_socket: buffered_socket, roads: roads, registry: registery}
    {:ok, state}
  end

  def handle_info({:tcp, _socket, _payload}, %__MODULE__{} = state) do
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %__MODULE__{} = state) do
    {:noreply, state}
  end
end
