defmodule Tcp.AsyncServer do
  @moduledoc """
  The async server handles new TCP connections by running your handler
  module in a new, supervised process.

  ## Setup

  Add this module to the application's children including the supervisor.
  Your handler module must implement `child_spec(socket)`, e.g. by implementing
  `GenServer`.

  ```
  children = [
    Tcp.AsyncServer.ConnectionSupervisor,
    {Tcp.AsyncServer, [port: port, handler_mod: YourHandlerMod]}
  ]
  Supervisor.start_link(children, strategy: :one_for_one)
  ```

  Optionally your server may implement `packet_mode/0` to specify if requests
  should be processed before being received. The return value could be any packet
  type as described by `:inet` but generally this will be `:line`, which results
  in packets being received only when they end in a newline. The default value is
  `:raw` which does not process the packet.
  """
  use GenServer

  require Logger

  alias Tcp.AsyncServer.ConnectionSupervisor

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    port = Keyword.fetch!(args, :port)
    connection_handler_module = Keyword.fetch!(args, :handler_mod)

    packet_mode =
      if function_exported?(connection_handler_module, :packet_mode, 0) do
        connection_handler_module.packet_mode()
      else
        :raw
      end

    opts = [:binary, active: false, packet: packet_mode]
    {:ok, listen_socket} = :gen_tcp.listen(port, opts)

    # === Fix for packet mode `:line` and small buffer sizes ===
    # Packet mode `:line` will return a non-newline delimited payload if the payload
    # is larger than the buffer size. However the handler module is expecting at least 1
    # complete line though.
    # To prevent this issue we simply set the buffer size to an unusually large number
    # that will cover all Protohackers challenges.
    # The recbuf should also be larger than the buffer to prevent "performance issues"
    # according to the documentation. For simplicity we use the same size of the
    # buffer, although Erlang will most likely increase that value for us,
    # ensuring that recbuf is definitely much larger than buffer.
    # Note: we could also use packet_size to reject packets larger than our buffer size
    # but that might obfuscate the problem.
    :ok = :inet.setopts(listen_socket, buffer: 100_000, recbuf: 100_000)

    {:ok, [buffer: buffer_size, recbuf: receive_buffer_size]} =
      :inet.getopts(listen_socket, [:buffer, :recbuf])

    Logger.info(
      "Socket started with buffer size of #{buffer_size} and receive buffer size of #{receive_buffer_size}"
    )

    send(self(), :start)

    {:ok, {listen_socket, connection_handler_module}}
  end

  @impl GenServer
  def handle_info(:start, {listen_socket, connection_handler_module}) do
    case :gen_tcp.accept(listen_socket, 500) do
      {:ok, socket} ->
        ConnectionSupervisor.start_child!(connection_handler_module.child_spec(socket))

      {:error, :timeout} ->
        :ok
    end

    send(self(), :start)
    {:noreply, {listen_socket, connection_handler_module}}
  end
end