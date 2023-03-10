defmodule Protohackex.NeedForLessSpeed.Client.DispatcherTest do
  use ExUnit.Case

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Message}
  alias Protohackex.NeedForLessSpeed.Client.Dispatcher

  test "dispatchers cannot identify again as dispatchers" do
    dispatcher_pid =
      start_link_supervised!({Dispatcher, [socket: BufferedSocket.new(self()), roads: [123]]})

    Tcp.send_to_active_server(dispatcher_pid, self(), Message.encode_dispatcher_id([39, 1028]))

    ProcessHelper.assert_died(
      dispatcher_pid,
      200,
      "Dispatcher failed to die after re-identifying"
    )
  end

  test "dispatchers cannot re-identify as cameras" do
    dispatcher_pid =
      start_link_supervised!({Dispatcher, [socket: BufferedSocket.new(self()), roads: [123]]})

    Tcp.send_to_active_server(dispatcher_pid, self(), Message.encode_camera_id(42, 8, 80))

    ProcessHelper.assert_died(
      dispatcher_pid,
      200,
      "Dispatcher failed to die after re-identifying"
    )
  end

  test "dispatchers do not accept plates" do
    dispatcher_pid =
      start_link_supervised!({Dispatcher, [socket: BufferedSocket.new(self()), roads: [123]]})

    Tcp.send_to_active_server(dispatcher_pid, self(), Message.encode_plate("UN1X", 80))

    ProcessHelper.assert_died(
      dispatcher_pid,
      200,
      "Dispatcher failed to die after re-identifying"
    )
  end
end
