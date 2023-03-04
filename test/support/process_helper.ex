defmodule ProcessHelper do
  def assert_died(pid, timeout, failure_message) do
    if timeout < 0 do
      ExUnit.Assertions.refute(false, failure_message)
    else
      Process.sleep(10)

      if Process.alive?(pid) do
        assert_died(pid, timeout - 10, failure_message)
      end
    end
  end
end
