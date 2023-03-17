defmodule Protohackex.NeedForLessSpeed.Dispatch do
  @moduledoc """
  Dispatch handles the dispatch of tickets for all roads.
  """

  use GenServer

  alias Protohackex.NeedForLessSpeed.Violation
  alias Protohackex.NeedForLessSpeed.Client.{Dispatcher, Supervisor}

  require Logger

  defstruct [:client_supervisor, :dispatchers_table, :ticket_queue_table, :ticket_log_table]

  # Interface

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    client_supervisor = Keyword.get(opts, :client_supervisor, Supervisor)

    GenServer.start_link(__MODULE__, client_supervisor, name: name)
  end

  def list_dispatchers(dispatch \\ __MODULE__, road_id) do
    GenServer.call(dispatch, {:list_dispatchers, road_id})
  end

  def start_dispatcher(dispatch \\ __MODULE__, socket, roads) do
    GenServer.call(dispatch, {:start_dispatcher, socket, roads})
  end

  def add_dispatcher(dispatch \\ __MODULE__, road_id, dispatcher_pid) do
    GenServer.cast(dispatch, {:add_dispatcher, road_id, dispatcher_pid})
    dispatch
  end

  def remove_dispatcher(dispatch \\ __MODULE__, road_id, dispatcher_pid) do
    GenServer.cast(dispatch, {:remove_dispatcher, road_id, dispatcher_pid})
    dispatch
  end

  def issue_ticket(dispatch \\ __MODULE__, %Violation{} = violation) do
    GenServer.cast(dispatch, {:queue_ticket, violation})
    dispatch
  end

  # GenServer callbacks

  def init(client_supervisor) do
    dispatchers_table = :ets.new(:dispatchers, [:private, :bag])
    ticket_queue_table = :ets.new(:ticket_queue, [:private])
    ticket_log_table = :ets.new(:ticket_log, [:private])

    {:ok,
     %__MODULE__{
       dispatchers_table: dispatchers_table,
       ticket_queue_table: ticket_queue_table,
       ticket_log_table: ticket_log_table,
       client_supervisor: client_supervisor
     }}
  end

  def handle_call({:list_dispatchers, road_id}, _from, %__MODULE__{} = dispatch) do
    dispatchers = list_dispatchers_from_ets(dispatch, road_id)

    {:reply, dispatchers, dispatch}
  end

  def handle_call({:start_dispatcher, socket, roads}, _from, %__MODULE__{} = dispatch) do
    {:ok, dispatcher_pid} = Supervisor.start_dispatcher(dispatch.client_supervisor, socket, roads)

    for road <- roads do
      add_dispatcher(self(), road, dispatcher_pid)
    end

    {:reply, dispatcher_pid, dispatch}
  end

  def handle_cast({:add_dispatcher, road_id, dispatcher_pid}, %__MODULE__{} = dispatch) do
    case :ets.match_object(dispatch.dispatchers_table, {road_id, dispatcher_pid}) do
      [{^road_id, ^dispatcher_pid}] -> :ok
      [] -> :ets.insert(dispatch.dispatchers_table, {road_id, dispatcher_pid})
    end

    # Monitor the dispatcher so we can deregister it automatically if the client disconnects.
    Process.monitor(dispatcher_pid)

    send(self(), {:process_queue, road_id})

    {:noreply, dispatch}
  end

  def handle_cast({:remove_dispatcher, road_id, dispatcher_pid}, %__MODULE__{} = dispatch) do
    :ets.match_delete(dispatch.dispatchers_table, {road_id, dispatcher_pid})

    {:noreply, dispatch}
  end

  def handle_cast({:queue_ticket, violation}, %__MODULE__{} = dispatch) do
    Logger.info("Queueing ticket for #{violation.plate} on road #{violation.road}")

    queue =
      get_ticket_queue(dispatch, violation.road)
      |> then(fn queue -> :queue.in(violation, queue) end)

    :ets.insert(dispatch.ticket_queue_table, {violation.road, queue})

    send(self(), {:process_queue, violation.road})

    {:noreply, dispatch}
  end

  def handle_info({:process_queue, road_id}, %__MODULE__{} = dispatch) do
    dispatchers = list_dispatchers_from_ets(dispatch, road_id)

    if !Enum.empty?(dispatchers) do
      # Implementation detail: we get to pick the dispatcher that will process the ticket.
      # For consistency sake we just pick the last one to register, which is always added
      # to the front of the list.
      [dispatcher | _] = dispatchers

      get_ticket_queue(dispatch, road_id)
      |> :queue.to_list()
      |> Enum.each(fn violation ->
        maybe_send_ticket(dispatch, dispatcher, violation)
      end)

      :ets.insert(dispatch.ticket_queue_table, {road_id, :queue.new()})
    else
      Logger.info("No dispatchers for road #{road_id}")
    end

    {:noreply, dispatch}
  end

  def handle_info({:DOWN, _ref, :process, dispatcher_pid, _reason}, %__MODULE__{} = dispatch) do
    :ets.match_delete(dispatch.dispatchers_table, {:"$1", dispatcher_pid})

    {:noreply, dispatch}
  end

  defp list_dispatchers_from_ets(dispatch, road_id) do
    :ets.match(dispatch.dispatchers_table, {road_id, :"$1"})
    |> List.flatten()
  end

  defp get_ticket_queue(dispatch, road_id) do
    case :ets.lookup(dispatch.ticket_queue_table, road_id) do
      [{^road_id, queue}] -> queue
      [] -> :queue.new()
    end
  end

  defp maybe_send_ticket(%__MODULE__{} = dispatch, dispatcher, %Violation{} = violation) do
    if !already_sent_today?(dispatch, violation) do
      Dispatcher.send_ticket(dispatcher, violation)

      ticket_log = lookup_ticket_log(dispatch, violation.road, violation.plate)

      updated_ticket_log =
        ticket_log
        |> MapSet.put(floor(violation.timestamp1 / 86400))
        |> MapSet.put(floor(violation.timestamp2 / 86400))

      :ets.insert(
        dispatch.ticket_log_table,
        {{violation.road, violation.plate}, updated_ticket_log}
      )
    else
      Logger.info(
        "Already sent ticket for #{violation.plate} on road #{violation.road} on timestamps #{violation.timestamp1} and #{violation.timestamp2}"
      )
    end

    :ok
  end

  defp already_sent_today?(%__MODULE__{} = dispatch, %Violation{} = violation) do
    plate_ticket_log = lookup_ticket_log(dispatch, violation.road, violation.plate)
    date1 = floor(violation.timestamp1 / 86400)
    date2 = floor(violation.timestamp2 / 86400)

    MapSet.member?(plate_ticket_log, date1) || MapSet.member?(plate_ticket_log, date2)
  end

  defp lookup_ticket_log(dispatch, road_id, plate) do
    case :ets.lookup(dispatch.ticket_log_table, {road_id, plate}) do
      [{{^road_id, ^plate}, ticket_log}] -> ticket_log
      [] -> MapSet.new()
    end
  end
end
