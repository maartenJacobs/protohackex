defmodule Protohackex.NeedForLessSpeed.Client.Dispatcher do
  @moduledoc """
  Client connection to ticket sender responsible for multiple roads.
  """

  use GenServer, restart: :transient

  alias Protohackex.Tcp
  alias Protohackex.NeedForLessSpeed.{BufferedSocket, Heart, Message, Violation}

  require Logger

  defstruct [:buffered_socket, :heart, :roads, :registry]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    roads = Keyword.fetch!(opts, :roads)
    registry = Keyword.get(opts, :registry, RoadRegistry)
    heart = Keyword.get(opts, :heart, Heart)

    GenServer.start_link(__MODULE__, {socket, roads, registry, heart})
  end

  @spec send_ticket(pid() | atom(), Violation.t()) :: :ok
  def send_ticket(dispatcher_id, violation) do
    GenServer.cast(dispatcher_id, {:send_ticket, violation})
  end

  # GenServer callbacks

  def init({buffered_socket, roads, registry, heart}) do
    Logger.info("Dispatcher connected", socket: inspect(buffered_socket.socket))

    # Make sure to process any outstanding messages!
    buffered_socket = BufferedSocket.send_all_messages(buffered_socket)

    state = %__MODULE__{
      buffered_socket: buffered_socket,
      roads: roads,
      registry: registry,
      heart: heart
    }

    {:ok, state}
  end

  def handle_cast({:send_ticket, violation}, %__MODULE__{} = state) do
    Logger.info("Sending ticket for violation: #{inspect(violation)}",
      socket: inspect(state.buffered_socket.socket)
    )

    Tcp.send_to_client(state.buffered_socket.socket, Message.encode_ticket(violation))

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, payload}, %__MODULE__{} = state) do
    buffered_socket =
      BufferedSocket.add_payload(state.buffered_socket, payload)
      |> BufferedSocket.send_all_messages()

    state = struct!(state, buffered_socket: buffered_socket)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %__MODULE__{} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:socket_message, {:want_heartbeat, interval_ms}}, %__MODULE__{} = state) do
    socket = state.buffered_socket.socket

    Heart.start_heartbeat(state.heart, socket, interval_ms)
    |> case do
      :ok ->
        {:noreply, state}

      {:error, :already_started} ->
        force_disconnect(state.buffered_socket.socket, "Too many heartbeats")
        {:stop, :normal, state}
    end
  end

  def handle_info({:socket_message, {message_type, _}}, %__MODULE__{} = state)
      when message_type == :camera_id or message_type == :dispatcher_id do
    force_disconnect(state.buffered_socket.socket, "you're already a dispatcher, buddy")
    {:stop, :normal, state}
  end

  def handle_info({:socket_message, {:plate, _, _}}, %__MODULE__{} = state) do
    force_disconnect(state.buffered_socket.socket, "you're not a camera")
    {:stop, :normal, state}
  end

  def handle_info({:socket_message, :invalid_message}, %__MODULE__{} = state) do
    force_disconnect(state.buffered_socket.socket, "What are you saying?")
    {:stop, :normal, state}
  end

  defp force_disconnect(socket, message) do
    Logger.info("Dispatcher forcefully disconnected", socket: inspect(socket))
    Tcp.send_to_client(socket, Message.encode_error(message))
    Tcp.close(socket)
  end
end
