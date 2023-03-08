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
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Heart, Message, Road, RoadRegistry}

  require Logger

  defstruct [:buffered_socket, :heart, :registry]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    registry = Keyword.get(opts, :registry, RoadRegistry)
    heart = Keyword.get(opts, :heart, Heart)

    GenServer.start_link(__MODULE__, {socket, registry, heart})
  end

  # GenServer callbacks

  def init({socket, registry, heart}) do
    Logger.info("Unidentified client connected", socket: inspect(socket))
    send(self(), :receive)

    {:ok,
     %__MODULE__{buffered_socket: BufferedSocket.new(socket), registry: registry, heart: heart}}
  end

  def handle_info(:receive, %__MODULE__{} = state) do
    # TODO: switch to active mode and confirm that :gen_tcp transfers pending TCP messages
    # to new controlling process.
    updated_state =
      case Tcp.receive(state.buffered_socket.socket, 100) do
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

  def handle_info({:socket_message, {:want_heartbeat, interval_ms}}, state) do
    # Unlike the other handled message types, heartbeat does not change the flow of the
    # client, e.g. it doesn't identify the client. Therefore other messages may follow
    # it that need processing.
    buffered_socket = BufferedSocket.send_next_message(state.buffered_socket)
    state = struct!(state, buffered_socket: buffered_socket)

    socket = state.buffered_socket.socket

    Heart.start_heartbeat(state.heart, socket, interval_ms)
    |> case do
      :ok ->
        {:noreply, state}

      {:error, :already_started} ->
        Logger.info(
          "Unidentified client forcibly disconnected because of duplicate heartbeat requests",
          socket: inspect(socket)
        )

        Tcp.send_to_client(socket, Message.encode_error("Too many heartbeats"))
        Tcp.close(socket)
        {:stop, :normal, state}
    end
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
