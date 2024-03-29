defmodule Protohackex.NeedForLessSpeed.RoadTest do
  use ExUnit.Case

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Message, Road, Violation}

  # Smoke test for now.
  test "cameras can connect and disconnect" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    assert [self()] == Road.connected_cameras(road_pid)

    Tcp.notify_socket_closure(road_pid, self())
    assert [] == Road.connected_cameras(road_pid)
  end

  test "cameras cannot re-identify as dispatchers" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    Tcp.send_to_active_server(road_pid, self(), Message.encode_dispatcher_id([1, 42]))

    assert [] == Road.connected_cameras(road_pid)
    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end

  test "cameras cannot identify again as cameras" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    Tcp.send_to_active_server(road_pid, self(), Message.encode_camera_id(42, 8, 80))

    assert [] == Road.connected_cameras(road_pid)
    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end

  test "handles server->client message (error) by disconnecting road" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    Tcp.send_to_active_server(road_pid, self(), Message.encode_error("Invalid message"))

    assert [] == Road.connected_cameras(road_pid)
    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end

  test "handles server->client message (ticket) by disconnecting road" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    Tcp.send_to_active_server(
      road_pid,
      self(),
      Message.encode_ticket(%Violation{
        mile1: 8,
        mile2: 9,
        plate: "UN1X",
        timestamp1: 100_000,
        timestamp2: 102_092,
        road: 1,
        speed_mph: 80
      })
    )

    assert [] == Road.connected_cameras(road_pid)
    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end

  test "handles server->client message (heartbeat) by disconnecting road" do
    road_pid = start_link_supervised!({Road, [road_id: 42]})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    Tcp.send_to_active_server(road_pid, self(), Message.encode_heartbeat())

    assert [] == Road.connected_cameras(road_pid)
    assert {:ok, <<16::unsigned-integer-8, _rest::binary>>} = Tcp.receive_payload()
  end
end
