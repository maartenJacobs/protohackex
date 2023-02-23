defmodule Protohackex.Tcp do
  @moduledoc """
  Common TCP operations.

  ## Testing

  The functions in this module are designed to behave differently when compiled for
  testing so actual sockets do not need to be created.
  """

  if Mix.env() == :test do
    def receive(socket, timeout) do
      receive do
        {:receive, ^socket, response} ->
          response
      after
        timeout ->
          {:error, timeout}
      end
    end
  else
    def receive(socket, timeout) do
      :gen_tcp.recv(socket, 0, timeout)
    end
  end

  def switch_to_active_mode(socket, road_pid) do
    if Mix.env() == :test do
      # When testing we send messages directly to processes instead of relying on
      # `:inet` behaviour. In that case we can skip any socket operations like these.
      :ok
    else
      # Word to the wise: this will fail if you are passing around the socket
      # between processes a lot (in my case: accept server -> unidentified -> road).
      # Each step of the way, make sure `:gen_tcp.controlling_process/2` is called
      # when handing the socket.s
      :ok = :gen_tcp.controlling_process(socket, road_pid)
      :inet.setopts(socket, active: true)
    end
  end

  # ===
  # Only for testing
  # ===

  if Mix.env() == :test do
    def notify_socket_closure(to_pid, socket) do
      send(to_pid, {:tcp_closed, socket})
    end

    def send(to_pid, from_socket, payload) do
      send(to_pid, {:receive, from_socket, {:ok, payload}})
    end
  end
end
