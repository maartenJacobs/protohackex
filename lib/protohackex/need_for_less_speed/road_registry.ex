defmodule Protohackex.NeedForLessSpeed.RoadRegistry do
  @moduledoc """
  Central registry of roads and associated dispatchers.
  """

  use GenServer

  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Road, Violation}
  alias Protohackex.NeedForLessSpeed.Client.{Supervisor, Dispatcher}

  @typep road_data :: %{pid: pid(), ticket_queue: [Violation.t()]}

  @type t :: %__MODULE__{
          client_supervisor: pid() | atom(),
          roads: %{Road.road_id() => road_data()},
          dispatchers: %{Road.road_id() => [pid()]}
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

  @spec dispatch_ticket(pid() | atom(), Violation.t()) :: :ok
  def dispatch_ticket(registry, %Violation{} = violation) do
    GenServer.cast(registry, {:queue_ticket, violation})
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
        road_data = %{pid: road_pid, ticket_queue: []}
        struct!(registry, roads: Map.put(registry.roads, road_id, road_data))
      end

    {:reply, registry.roads[road_id].pid, registry}
  end

  def handle_call({:start_dispatcher, socket, roads}, _from, %__MODULE__{} = registry) do
    {:ok, dispatcher_pid} = Supervisor.start_dispatcher(registry.client_supervisor, socket, roads)
    registry = record_dispatcher(registry, roads, dispatcher_pid)
    {:reply, dispatcher_pid, registry}
  end

  def handle_call({:get_dispatchers, road}, _from, %__MODULE__{} = registry) do
    {:reply, Map.get(registry.dispatchers, road, []), registry}
  end

  def handle_cast({:queue_ticket, %Violation{} = violation}, %__MODULE__{} = registry) do
    registry =
      put_in(
        registry.roads[violation.road].ticket_queue,
        [violation | registry.roads[violation.road].ticket_queue]
      )

    send(self(), {:process_queue, violation.road})
    {:noreply, registry}
  end

  def handle_info({:process_queue, road}, %__MODULE__{} = registry) do
    dispatchers = Map.get(registry.dispatchers, road, [])

    registry =
      if registry.roads[road] && !Enum.empty?(dispatchers) do
        # Implementation detail: we get to pick the dispatcher that will process the ticket.
        # For consistency sake we just pick the last one to register, which is always added
        # to the front of the list.
        [dispatcher | _] = dispatchers

        Enum.each(registry.roads[road].ticket_queue, fn violation ->
          Dispatcher.send_ticket(dispatcher, violation)
        end)

        put_in(registry.roads[road].ticket_queue, [])
      else
        registry
      end

    {:noreply, registry}
  end

  defp record_dispatcher(%__MODULE__{} = registry, roads, dispatcher_pid) do
    updated_dispatchers =
      for road <- roads, reduce: registry.dispatchers do
        dispatchers ->
          put_in(dispatchers[road], [dispatcher_pid | Map.get(dispatchers, road, [])])
      end

    for road <- roads do
      send(self(), {:process_queue, road})
    end

    struct!(registry, dispatchers: updated_dispatchers)
  end
end
