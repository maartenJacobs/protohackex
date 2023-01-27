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

    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: false])
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
