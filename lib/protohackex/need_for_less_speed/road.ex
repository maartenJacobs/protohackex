defmodule Protohackex.NeedForLessSpeed.Road do
  use GenServer

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Heart, Message, RoadRegistry, SpeedChecker}

  require Logger

  @type road_id :: non_neg_integer()
  @type camera_road_offset :: integer()
  @type plate :: String.t()

  @type t :: %__MODULE__{
          road_registry: pid() | atom(),
          heart: pid() | atom(),
          road_id: road_id(),
          speed_checker: SpeedChecker.t(),
          camera_clients: %{any() => BufferedSocket.t()}
        }
  defstruct [
    :road_registry,
    :heart,
    :road_id,
    speed_checker: %SpeedChecker{},
    camera_clients: %{}
  ]

  # Interface

  def start_link(opts) do
    road_id = Keyword.fetch!(opts, :road_id)
    road_registry = Keyword.get(opts, :road_registry, RoadRegistry)
    heart = Keyword.get(opts, :heart, Heart)

    GenServer.start_link(__MODULE__, {road_id, road_registry, heart})
  end

  @doc """
  Returns a list of connected cameras.

  This is mostly for debugging and testing.
  """
  @spec connected_cameras(pid()) :: [any()]
  def connected_cameras(road_pid) do
    GenServer.call(road_pid, :connected_cameras)
  end

  @type camera :: %{
          mile: non_neg_integer(),
          limit_mph: non_neg_integer(),
          # Superfluous but could be used for double checking.
          road: road_id()
        }

  @spec add_camera(pid(), BufferedSocket.t(), camera()) :: :ok
  def add_camera(road_pid, buffered_socket, camera) do
    # Note: ordering might be important here. We cast a message to register the camera,
    # and then switch the socket to active mode to receive socket payloads as messages.
    # If we reverse the order, we may receive payloads before the camera is registered.

    GenServer.cast(road_pid, {:add_camera, buffered_socket, camera})
    Tcp.controlling_process(buffered_socket.socket, road_pid)
    :ok
  end

  # GenServer callbacks

  def init({road_id, road_registry, heart}) do
    {:ok, %__MODULE__{road_id: road_id, road_registry: road_registry, heart: heart}}
  end

  def handle_info({:tcp, camera_socket, payload}, %__MODULE__{} = state) do
    state =
      state
      |> record_payload(camera_socket, payload)
      |> process_all_messages(camera_socket)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, camera_socket}, %__MODULE__{} = state) do
    Logger.info("Camera disconnected", socket: inspect(camera_socket))
    {:noreply, deregister_camera(state, camera_socket)}
  end

  def handle_cast({:add_camera, buffered_socket, camera}, %__MODULE__{} = state) do
    Logger.info("Camera connected", socket: inspect(buffered_socket.socket))

    state =
      state
      |> register_camera(buffered_socket, camera)
      |> process_all_messages(buffered_socket.socket)

    {:noreply, state}
  end

  def handle_call(:connected_cameras, _from, %__MODULE__{} = state) do
    {:reply, Map.keys(state.camera_clients), state}
  end

  defp register_camera(%__MODULE__{} = state, buffered_socket, camera) do
    struct(
      state,
      camera_clients: Map.put(state.camera_clients, buffered_socket.socket, buffered_socket),
      speed_checker:
        SpeedChecker.add_camera(
          state.speed_checker,
          state.road_id,
          buffered_socket.socket,
          camera.mile,
          camera.limit_mph
        )
    )
  end

  defp deregister_camera(%__MODULE__{} = state, camera_socket) do
    struct!(
      state,
      speed_checker: SpeedChecker.remove_camera(state.speed_checker, camera_socket),
      camera_clients: Map.delete(state.camera_clients, camera_socket)
    )
  end

  defp record_payload(state, camera_socket, payload) do
    buffered_socket = BufferedSocket.add_payload(state.camera_clients[camera_socket], payload)

    struct!(state, camera_clients: Map.put(state.camera_clients, camera_socket, buffered_socket))
  end

  defp process_all_messages(state, camera_socket) do
    {buffered_socket, messages} =
      BufferedSocket.extract_all_messages(state.camera_clients[camera_socket])

    state =
      struct!(state, camera_clients: Map.put(state.camera_clients, camera_socket, buffered_socket))

    for message <- messages, reduce: state do
      state ->
        process_message(state, camera_socket, message)
    end
  end

  defp process_message(%__MODULE__{} = state, camera_socket, {:plate, plate, timestamp}) do
    {checker, violations} =
      SpeedChecker.add_observation(state.speed_checker, camera_socket, plate, timestamp)

    Logger.info("Plate detected and found #{length(violations)} violations",
      socket: inspect(camera_socket)
    )

    for violation <- violations do
      RoadRegistry.dispatch_ticket(state.road_registry, violation)
    end

    struct!(state, speed_checker: checker)
  end

  defp process_message(%__MODULE__{} = state, camera_socket, {:want_heartbeat, interval_ms}) do
    Heart.start_heartbeat(state.heart, camera_socket, interval_ms)
    |> case do
      :ok ->
        state

      {:error, :already_started} ->
        Logger.info(
          "Camera forcibly disconnected because of duplicate heartbeat requests",
          socket: inspect(camera_socket)
        )

        Tcp.send_to_client(camera_socket, Message.encode_error("Too many heartbeats"))
        Tcp.close(camera_socket)

        deregister_camera(state, camera_socket)
    end
  end

  defp process_message(state, camera_socket, {message_type, _})
       when message_type == :camera_id or message_type == :dispatcher_id do
    Logger.info("Camera forcefully disconnected", socket: inspect(camera_socket))
    Tcp.send_to_client(camera_socket, Message.encode_error("you're already a camera, buddy"))
    Tcp.close(camera_socket)

    deregister_camera(state, camera_socket)
  end

  defp process_message(state, _camera_socket, :unknown) do
    state
  end
end
