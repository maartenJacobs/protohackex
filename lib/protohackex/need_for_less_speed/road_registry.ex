defmodule Protohackex.NeedForLessSpeed.RoadRegistry do
  @moduledoc """
  Mapping of road ID to road PID.
  """

  use GenServer

  alias Protohackex.NeedForLessSpeed.BufferedSocket
  alias Protohackex.NeedForLessSpeed.Client.Supervisor

  @type t :: %__MODULE__{
          client_supervisor: pid() | atom(),
          roads: %{any() => pid()},
          dispatchers: %{any() => [pid()]}
        }

  defstruct [:client_supervisor, :roads, :dispatchers]

  # Interface

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    client_supervisor = Keyword.get(opts, :client_supervisor, Supervisor)

    GenServer.start_link(__MODULE__, client_supervisor, name: name)
  end

  @spec get_road(pid() | atom(), any()) :: pid()
  def get_road(registry, road_id) do
    GenServer.call(registry, {:get_road, road_id})
  end

  @spec start_dispatcher(pid() | atom(), BufferedSocket.t(), [non_neg_integer()]) :: pid()
  def start_dispatcher(registry, socket, roads) do
    GenServer.call(registry, {:start_dispatcher, socket, roads})
  end

  @spec get_dispatchers(pid() | atom(), non_neg_integer()) :: [pid()]
  def get_dispatchers(registry, road) do
    GenServer.call(registry, {:get_dispatchers, road})
  end

  # GenServer callbacks

  def init(client_supervisor) do
    {:ok, %__MODULE__{client_supervisor: client_supervisor, roads: %{}, dispatchers: %{}}}
  end

  def handle_call({:get_road, road_id}, _from, %__MODULE__{} = registry) do
    registry =
      if Map.has_key?(registry.roads, road_id) do
        registry
      else
        {:ok, road_pid} = Supervisor.start_road(registry.client_supervisor, road_id)
        struct!(registry, roads: Map.put(registry.roads, road_id, road_pid))
      end

    {:reply, registry.roads[road_id], registry}
  end

  def handle_call({:start_dispatcher, socket, roads}, _from, %__MODULE__{} = registry) do
    {:ok, dispatcher_pid} = Supervisor.start_dispatcher(registry.client_supervisor, socket, roads)
    registry = record_dispatcher(registry, roads, dispatcher_pid)
    {:reply, dispatcher_pid, registry}
  end

  def handle_call({:get_dispatchers, road}, _from, %__MODULE__{} = registry) do
    {:reply, Map.get(registry.dispatchers, road, []), registry}
  end

  defp record_dispatcher(%__MODULE__{} = registry, roads, dispatcher_pid) do
    updated_dispatchers =
      for road <- roads, reduce: registry.dispatchers do
        dispatchers ->
          road_dispatchers = [dispatcher_pid | Map.get(dispatchers, road, [])]
          Map.put(dispatchers, road, road_dispatchers)
      end

    # TODO: Trigger queued tickets

    struct!(registry, dispatchers: updated_dispatchers)
  end
end
