defmodule Protohackex.NeedForLessSpeed.Client.Unidentified do
  @moduledoc """
  Initial connection handler before identification.
  """

  # This process will terminate normally when the client is identified so
  # a restart strategy other than `:permanent` is necessary.
  # `:transient` is the best choice because the process will only restart if
  # the termination is unexpected. `:temporary` would restart regardless
  # even if the client has been identified.
  use GenServer, restart: :transient

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.Road
  alias Protohackex.NeedForLessSpeed.RoadRegistry
  alias Protohackex.NeedForLessSpeed.BufferedSocket

  require Logger

  defstruct [:buffered_socket, :registry]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    registry = Keyword.get(opts, :registry, RoadRegistry)

    GenServer.start_link(__MODULE__, {socket, registry})
  end

  # GenServer callbacks

  def init({socket, registry}) do
    Logger.info("Unidentified client connected", socket: inspect(socket))
    send(self(), :receive)
    {:ok, %__MODULE__{buffered_socket: BufferedSocket.new(socket), registry: registry}}
  end

  def handle_info(:receive, %__MODULE__{} = state) do
    updated_state =
      case Tcp.receive(state.buffered_socket.socket, 500) do
        {:ok, payload} ->
          buffered_socket =
            BufferedSocket.add_payload(state.buffered_socket, payload)
            |> BufferedSocket.send_next_message()

          send(self(), :receive)
          struct!(state, buffered_socket: buffered_socket)

        {:error, :timeout} ->
          send(self(), :receive)
          state

        {:error, _} ->
          exit(:normal)
      end

    {:noreply, updated_state}
  end

  def handle_info({:socket_message, {:camera_id, camera}}, state) do
    register_camera(state, camera)
    {:stop, :normal, state}
  end

  def handle_info({:socket_message, {:dispatcher_id, roads}}, state) do
    register_dispatcher(state, roads)
    {:stop, :normal, state}
  end

  def handle_info({:socket_message, :unknown}, state) do
    {:noreply, state}
  end

  defp register_camera(%__MODULE__{} = state, camera) do
    RoadRegistry.get_road(state.registry, camera.road)
    |> Road.add_camera(state.buffered_socket, camera)
  end

  defp register_dispatcher(%__MODULE__{} = state, roads) do
    dispatcher_pid = RoadRegistry.start_dispatcher(state.registry, state.buffered_socket, roads)
    Tcp.switch_to_active_mode(state.buffered_socket.socket, dispatcher_pid)
    :ok
  end
end
