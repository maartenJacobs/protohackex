defmodule Protohackex.MobProxy do
  @moduledoc """
  Mob proxy acts like a chat server but really sends all your messages
  to the mob instead.
  """

  use GenServer

  require Logger

  # Interface

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    port = Keyword.fetch!(args, :port)

    # See TCP.AsyncServer for reasoning behind `buffer: 100_000`.
    {:ok, listen_socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, buffer: 100_000, recbuf: 100_000])

    send(self(), :accept)

    {:ok, {listen_socket, new_connections()}}
  end

  @impl GenServer

  def handle_info(:accept, {listen_socket, connections} = state) do
    updated_state =
      case :gen_tcp.accept(listen_socket, 0) do
        {:ok, socket} ->
          connections = connect_to_mob(connections, socket)
          {listen_socket, connections}

        {:error, _} ->
          state
      end

    Process.send_after(self(), :accept, 50)

    {:noreply, updated_state}
  end

  def handle_info({:tcp, socket, message}, {listen_socket, connections}) do
    forward(connections, socket, message)
    {:noreply, {listen_socket, connections}}
  end

  def handle_info({:tcp_closed, socket}, {listen_socket, connections}) do
    connections = close_connection(connections, socket)
    Logger.info("Client disconnected. #{Enum.count(connections)} remaining.")
    {:noreply, {listen_socket, connections}}
  end

  def handle_info(msg, state) do
    Logger.warn("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # "Business"/mob logic

  @tony_bogus_coin "7YWHMfk9JZe0LM0g1ZauHuiSxhI"
  @bogus_coin_format "7[a-zA-Z0-9]{25,34}"

  defp replace_boguscoin_address(message) do
    # Regex is tricky to get right so look away.

    bogus_coin_list = Regex.compile!("(^| )(#{@bogus_coin_format}( |$))+")
    bogus_coin_single = Regex.compile!(@bogus_coin_format)

    Regex.replace(bogus_coin_list, message, fn full_match, _group ->
      Regex.replace(bogus_coin_single, full_match, @tony_bogus_coin)
    end)
  end

  @proxy_host 'chat.protohackers.com'
  @proxy_port 16963

  defp connect_to_mob(connections, user_socket) do
    # Link the user to a new mob connection.
    {:ok, mob_socket} =
      :gen_tcp.connect(@proxy_host, @proxy_port, [
        :binary,
        packet: :line,
        buffer: 100_000,
        recbuf: 100_000
      ])

    add_connection(connections, user_socket, mob_socket)
  end

  defp forward(connections, socket, message) do
    message = replace_boguscoin_address(message)

    connection_counterpart(connections, socket)
    |> :gen_tcp.send(message)
  end

  defp close_connection(connections, socket) do
    counterpart = connection_counterpart(connections, socket)
    :gen_tcp.close(counterpart)

    remove_connection(connections, socket)
  end

  # Proxy connections mapping

  defp new_connections(), do: %{}

  defp add_connection(connections, client_socket, mob_socket) do
    connections
    |> Map.put(client_socket, mob_socket)
    |> Map.put(mob_socket, client_socket)
  end

  defp remove_connection(connections, socket) do
    counterpart = connection_counterpart(connections, socket)

    connections
    |> Map.drop([socket, counterpart])
  end

  defp connection_counterpart(connections, socket) do
    connections[socket]
  end
end
