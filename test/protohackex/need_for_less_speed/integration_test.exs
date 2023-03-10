defmodule Protohackex.NeedForLessSpeed.IntegrationTest do
  use ExUnit.Case

  alias Protohackex.NeedForLessSpeed.Message

  @moduletag :integration

  setup do
    {:ok, _} = Application.ensure_all_started(:protohackex)
    :ok
  end

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

  describe "heartbeats" do
    test "are sent to client at regular intervals" do
      {:ok, client_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
      send!(client_port, Message.encode_want_heartbeat(100))

      # No immediate heartbeat expected.
      assert {:error, :timeout} = :gen_tcp.recv(client_port, 0, 10)

      Process.sleep(100)
      {:ok, message} = :gen_tcp.recv(client_port, 0, 10)
      assert message == Message.encode_heartbeat()

      Process.sleep(100)
      {:ok, message} = :gen_tcp.recv(client_port, 0, 10)
      assert message == Message.encode_heartbeat()
    end

    test "can be sent to any type of client" do
      camera_1_port =
        connect!()
        |> send!(Message.encode_camera_id(42, 8, 80))
        |> send!(Message.encode_want_heartbeat(100))

      camera_2_port =
        connect!()
        |> send!(Message.encode_camera_id(42, 9, 80))
        |> send!(Message.encode_want_heartbeat(100))

      dispatcher_port =
        connect!()
        |> send!(Message.encode_dispatcher_id([42]))
        |> send!(Message.encode_want_heartbeat(100))

      Process.sleep(100)
      assert Message.encode_heartbeat() == receive!(camera_1_port, 10)
      assert Message.encode_heartbeat() == receive!(camera_2_port, 10)
      assert Message.encode_heartbeat() == receive!(dispatcher_port, 10)
    end

    test "is registered for client through identification" do
      {:ok, client_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
      send!(client_port, Message.encode_want_heartbeat(100))

      send!(client_port, Message.encode_camera_id(42, 8, 100))

      Process.sleep(100)
      {:ok, message} = :gen_tcp.recv(client_port, 0, 10)
      assert message == Message.encode_heartbeat()

      Process.sleep(100)
      {:ok, message} = :gen_tcp.recv(client_port, 0, 10)
      assert message == Message.encode_heartbeat()

      # When the client identified, the heartbeat doesn't stop or get disconnected from
      # the client. This also means that requesting another heartbeat after identification
      # should fail!
      send!(client_port, Message.encode_want_heartbeat(200))
      {:ok, message} = :gen_tcp.recv(client_port, 0, 100)
      assert message == Message.encode_error("Too many heartbeats")
    end

    test "cannot be registered multiple times for the same client" do
      {:ok, client_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
      send!(client_port, Message.encode_want_heartbeat(100))
      send!(client_port, Message.encode_want_heartbeat(200))

      {:ok, _heartbeat} = :gen_tcp.recv(client_port, 0, 150)
      {:ok, message} = :gen_tcp.recv(client_port, 0, 100)
      assert message == Message.encode_error("Too many heartbeats")
    end

    test "can be registered with 0ms interval" do
      {:ok, client_port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
      send!(client_port, Message.encode_want_heartbeat(0))

      # No messages should be sent as interval 0ms means no heartbeat.
      assert {:error, :timeout} = :gen_tcp.recv(client_port, 0, 200)

      # We can't register a new heartbeat though.
      send!(client_port, Message.encode_want_heartbeat(200))
      {:ok, message} = :gen_tcp.recv(client_port, 0, 100)
      assert message == Message.encode_error("Too many heartbeats")
    end
  end

  defp connect!() do
    {:ok, port} = :gen_tcp.connect({127, 0, 0, 0}, 8080, [:binary, active: false])
    port
  end

  defp send!(port, message) do
    :ok = :gen_tcp.send(port, message)
    port
  end

  defp receive!(port, timeout) do
    {:ok, response} = :gen_tcp.recv(port, 0, timeout)
    response
  end
end
