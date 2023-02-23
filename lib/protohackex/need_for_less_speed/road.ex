defmodule Protohackex.NeedForLessSpeed.Road do
  use GenServer

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.BufferedSocket
  alias Protohackex.NeedForLessSpeed.SpeedChecker

  require Logger

  @type t :: %__MODULE__{
          road_id: integer(),
          speed_checker: SpeedChecker.t(),
          camera_clients: %{any() => BufferedSocket.t()}
        }
  defstruct [:road_id, speed_checker: %SpeedChecker{}, camera_clients: %{}]

  # Interface

  def start_link(road_id) do
    GenServer.start_link(__MODULE__, road_id)
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
          road: non_neg_integer()
        }

  @spec add_camera(pid(), BufferedSocket.t(), camera()) :: :ok
  def add_camera(road_pid, buffered_socket, camera) do
    # Note: ordering might be important here. We cast a message to register the camera,
    # and then switch the socket to active mode to receive socket payloads as messages.
    # If we reverse the order, we may receive payloads before the camera is registered.

    GenServer.cast(road_pid, {:add_camera, buffered_socket, camera})
    Tcp.switch_to_active_mode(buffered_socket.socket, road_pid)
    :ok
  end

  # GenServer callbacks

  def init(road_id) do
    {:ok, %__MODULE__{road_id: road_id}}
  end

  def handle_info({:tcp, _camera_socket, _payload}, %__MODULE__{} = state) do
    {:noreply, state}
  end

  def handle_info({:tcp_closed, camera_socket}, %__MODULE__{} = state) do
    Logger.info("Camera #{inspect(camera_socket)} disconnected")
    {:noreply, deregister_camera(state, camera_socket)}
  end

  def handle_cast({:add_camera, buffered_socket, camera}, %__MODULE__{} = state) do
    Logger.info("Camera #{inspect(buffered_socket.socket)} connected")
    {:noreply, register_camera(state, buffered_socket, camera)}
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
end
