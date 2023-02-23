defmodule Protohackex.NeedForLessSpeed.RoadTest do
  use ExUnit.Case

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.Road
  alias Protohackex.NeedForLessSpeed.BufferedSocket

  # Smoke test for now.
  test "cameras can connect and disconnect" do
    road_pid = start_link_supervised!({Road, 42})

    Road.add_camera(road_pid, BufferedSocket.new(self()), %{
      mile: 8,
      limit_mph: 80,
      road: 42
    })

    assert [self()] == Road.connected_cameras(road_pid)

    Tcp.notify_socket_closure(road_pid, self())
    assert [] == Road.connected_cameras(road_pid)
  end
end
