defmodule Protohackex.NeedForLessSpeed.DispatchTest do
  use ExUnit.Case, async: true

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Dispatch, Message, Violation}
  alias Protohackex.NeedForLessSpeed.Client.Dispatcher

  setup context do
    {:ok, dispatch} = Dispatch.start_link(name: context.test)
    %{dispatch: dispatch}
  end

  test "dispatchers can be added and removed", %{dispatch: dispatch} do
    dispatch = Dispatch.add_dispatcher(dispatch, 1, self())
    assert Dispatch.list_dispatchers(dispatch, 1) == [self()]

    dispatch = Dispatch.add_dispatcher(dispatch, 2, self())
    assert Dispatch.list_dispatchers(dispatch, 1) == [self()]
    assert Dispatch.list_dispatchers(dispatch, 2) == [self()]

    dispatch = Dispatch.remove_dispatcher(dispatch, 1, self())
    assert Dispatch.list_dispatchers(dispatch, 1) == []
    assert Dispatch.list_dispatchers(dispatch, 2) == [self()]
  end

  test "roads can have multiple dispatchers", %{dispatch: dispatch} do
    {:ok, dispatcher1} = Agent.start(fn -> 0 end)
    {:ok, dispatcher2} = Agent.start(fn -> 0 end)

    dispatch = Dispatch.add_dispatcher(dispatch, 1, dispatcher1)
    dispatch = Dispatch.add_dispatcher(dispatch, 1, dispatcher2)

    assert Dispatch.list_dispatchers(dispatch, 1) == [dispatcher1, dispatcher2]
  end

  test "dispatchers are not doubly registered per road", %{dispatch: dispatch} do
    {:ok, dispatcher} = Agent.start(fn -> 0 end)

    dispatch = Dispatch.add_dispatcher(dispatch, 1, dispatcher)
    dispatch = Dispatch.add_dispatcher(dispatch, 1, dispatcher)

    assert Dispatch.list_dispatchers(dispatch, 1) == [dispatcher]
  end

  test "dispatcher is removed from all roads when it dies", %{dispatch: dispatch} do
    {:ok, dispatcher} = Agent.start(fn -> 0 end)

    dispatch =
      Dispatch.add_dispatcher(dispatch, 1, dispatcher)
      |> Dispatch.add_dispatcher(2, dispatcher)

    Agent.stop(dispatcher)

    assert Dispatch.list_dispatchers(dispatch, 1) == []
    assert Dispatch.list_dispatchers(dispatch, 2) == []
  end

  test "queued tickets are processed in order", %{dispatch: dispatch} do
    road_id = 1

    dispatcher_pid =
      start_link_supervised!({Dispatcher, [socket: BufferedSocket.new(self()), roads: []]})

    Dispatch.add_dispatcher(dispatch, road_id, dispatcher_pid)

    violation1 = %Violation{
      mile1: 8,
      mile2: 9,
      plate: "UN1X",
      timestamp1: 100_000,
      timestamp2: 102_092,
      road: road_id,
      speed_mph: 80
    }

    violation2 = %Violation{
      mile1: 8,
      mile2: 9,
      plate: "UN1X",
      timestamp1: 0,
      timestamp2: 45,
      road: road_id,
      speed_mph: 80
    }

    violation3 = %Violation{
      mile1: 8,
      mile2: 9,
      plate: "UN1X",
      timestamp1: 30_399_371,
      timestamp2: 30_399_372,
      road: road_id,
      speed_mph: 80
    }

    Dispatch.issue_ticket(dispatch, violation1)
    Dispatch.issue_ticket(dispatch, violation2)
    Dispatch.issue_ticket(dispatch, violation3)

    assert_ticket_dispatched(violation1)
    assert_ticket_dispatched(violation2)
    assert_ticket_dispatched(violation3)
  end

  test "only 1 ticket is sent per day per plate", %{dispatch: dispatch} do
    road_id = 1

    dispatcher_pid =
      start_link_supervised!({Dispatcher, [socket: BufferedSocket.new(self()), roads: []]})

    Dispatch.add_dispatcher(dispatch, road_id, dispatcher_pid)

    violation = %Violation{
      mile1: 8,
      mile2: 9,
      plate: "UN1X",
      timestamp1: 0,
      timestamp2: 45,
      road: road_id,
      speed_mph: 80
    }

    Dispatch.issue_ticket(dispatch, violation)
    assert_ticket_dispatched(violation)

    Dispatch.issue_ticket(dispatch, violation)
    assert_no_ticket_dispatched()

    Dispatch.issue_ticket(dispatch, %Violation{
      mile1: 8,
      mile2: 9,
      plate: "UN1X",
      timestamp1: 100,
      timestamp2: 1000,
      road: road_id,
      speed_mph: 80
    })

    assert_no_ticket_dispatched()
  end

  defp assert_ticket_dispatched(violation) do
    {:ok, message} = Tcp.receive_payload()
    assert message == Message.encode_ticket(violation)
  end

  defp assert_no_ticket_dispatched() do
    assert {:error, :timeout} = Tcp.receive_payload()
  end
end
