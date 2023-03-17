defmodule Protohackex.NeedForLessSpeed.Client.UnidentifiedTest do
  use ExUnit.Case
  alias Protohackex.NeedForLessSpeed.Dispatch
  alias Protohackex.NeedForLessSpeed.Message
  alias Protohackex.NeedForLessSpeed.RoadRegistry
  alias Protohackex.Tcp

  alias Protohackex.NeedForLessSpeed.Client.Unidentified
  alias Protohackex.NeedForLessSpeed.Client.Supervisor

  setup do
    client_supervisor = start_link_supervised!({Supervisor, [name: nil]})

    dispatch =
      start_link_supervised!({Dispatch, [name: nil, client_supervisor: client_supervisor]})

    registry =
      start_link_supervised!({RoadRegistry, [name: nil, client_supervisor: client_supervisor]})

    client =
      start_supervised!({Unidentified, [socket: self(), registry: registry, dispatch: dispatch]})

    %{client: client, registry: registry, dispatch: dispatch}
  end

  test "identify as camera", %{client: client, registry: registry} do
    camera_id_message =
      <<128::unsigned-integer-8, 42::unsigned-integer-16, 8::unsigned-integer-16,
        60::unsigned-integer-16>>

    Tcp.send_to_active_server(client, self(), camera_id_message)

    ProcessHelper.assert_died(
      client,
      500,
      "Unidentified client did not die after client identification"
    )

    road = RoadRegistry.get_road(registry, self())
    assert is_pid(road)
    assert Process.alive?(road)
  end

  test "identify as dispatcher", %{client: client, dispatch: dispatch} do
    roads = [29, 208, 10883]
    dispatcher_id_message = Message.encode_dispatcher_id(roads)

    Tcp.send_to_active_server(client, self(), dispatcher_id_message)

    ProcessHelper.assert_died(
      client,
      500,
      "Unidentified client did not die after client identification"
    )

    dispatchers =
      for road <- roads do
        Dispatch.list_dispatchers(dispatch, road)
      end
      |> List.flatten()
      |> Enum.uniq()

    assert length(dispatchers) == 1
    [dispatcher] = dispatchers
    assert is_pid(dispatcher)
    assert Process.alive?(dispatcher)
  end

  test "handles invalid messages by disconnecting", %{client: client} do
    Tcp.send_to_active_server(client, self(), Message.encode_plate("ABC123", 123))

    ProcessHelper.assert_died(
      client,
      500,
      "Unidentified client did not die after invalid message"
    )

    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end
end
