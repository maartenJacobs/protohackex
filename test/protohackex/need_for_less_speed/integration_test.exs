defmodule Protohackex.NeedForLessSpeed.IntegrationTest do
  use ExUnit.Case

  alias Protohackex.NeedForLessSpeed.Message

  setup do
    {:ok, _} = Application.ensure_all_started(:protohackex)
    :ok
  end

  @tag integration: true
  test "spec example" do
    road_id = 123
    speed_limit_mph = 60
    plate = "UN1X"

    # Register cameras at mile 8 and 9.
    {:ok, camera_1_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
    send!(camera_1_port, Message.encode_camera_id(road_id, 8, speed_limit_mph))

    {:ok, camera_2_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
    send!(camera_2_port, Message.encode_camera_id(road_id, 9, speed_limit_mph))

    # Register a ticket dispatcher handling this road.
    {:ok, dispatcher_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
    send!(dispatcher_port, Message.encode_dispatcher_id([road_id]))

    # Camera at mile 8 sees plate UN1X at timestamp 0.
    send!(camera_1_port, Message.encode_plate(plate, 0))

    # Camera at mile 9 sees plate UN1X at timestamp 45.
    send!(camera_2_port, Message.encode_plate(plate, 45))

    # 1 ticket should have been issued.
    {:ok, message} = :gen_tcp.recv(dispatcher_port, 0, 1000)
    assert message == Message.encode_ticket(plate, road_id, 8, 9, 0, 45, 80)
  end

  defp send!(port, message) do
    :ok = :gen_tcp.send(port, message)
  end
end
