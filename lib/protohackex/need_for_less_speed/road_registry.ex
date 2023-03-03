defmodule Protohackex.NeedForLessSpeed.RoadRegistry do
  @moduledoc """
  Mapping of road ID to road PID.
  """

  use GenServer

  alias Protohackex.NeedForLessSpeed.Client.Supervisor

  @type t :: %__MODULE__{
          roads: %{any() => pid()}
        }

  defstruct [:client_supervisor, :roads]

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

  # GenServer callbacks

  def init(client_supervisor) do
    {:ok, %__MODULE__{client_supervisor: client_supervisor, roads: %{}}}
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
end
