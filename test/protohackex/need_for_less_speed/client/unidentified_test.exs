defmodule Protohackex.NeedForLessSpeed.Client.UnidentifiedTest do
  use ExUnit.Case
  alias Protohackex.NeedForLessSpeed.RoadRegistry
  alias Protohackex.Tcp

  alias Protohackex.NeedForLessSpeed.Client.Unidentified
  alias Protohackex.NeedForLessSpeed.Client.Supervisor

  setup do
    client_supervisor = start_link_supervised!({Supervisor, [name: nil]})

    registry =
      start_link_supervised!({RoadRegistry, [name: nil, client_supervisor: client_supervisor]})

    client = start_supervised!({Unidentified, [socket: self(), registry: registry]})

    %{client: client, registry: registry}
  end

  test "identify as camera", %{client: client, registry: registry} do
    camera_id_message =
      <<128::unsigned-integer-8, 42::unsigned-integer-16, 8::unsigned-integer-16,
        60::unsigned-integer-16>>

    Tcp.send_to_server(client, self(), camera_id_message)

    assert_died client, 500, "Unidentified client did not die after client identification"

    road = RoadRegistry.get_road(registry, self())
    assert is_pid(road)
    assert Process.alive?(road)
  end

  defp assert_died(pid, timeout, failure_message) do
    if timeout < 0 do
      refute false, failure_message
    else
      Process.sleep(10)

      if Process.alive?(pid) do
        assert_died(pid, timeout - 10, failure_message)
      end
    end
  end
end