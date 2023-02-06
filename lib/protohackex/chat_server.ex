defmodule Protohackex.ChatServer do
  @moduledoc """
  ChatServer serves a single shared chat room.

  The chat server handles accepting new connections and managing their lifecycle.
  """

  use GenServer

  require Logger

  alias Protohackex.Chat.{Room, User}

  @welcome_message "Welcome to budgetchat! What shall I call you?"

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

    {:ok, {listen_socket, Room.new()}}
  end

  @impl GenServer

  def handle_info(:accept, {listen_socket, room} = state) do
    updated_state =
      case :gen_tcp.accept(listen_socket, 0) do
        {:ok, user_socket} ->
          room = user_connected(user_socket, room)
          {listen_socket, room}

        {:error, _} ->
          state
      end

    Process.send_after(self(), :accept, 50)

    {:noreply, updated_state}
  end

  def handle_info({:tcp, user_socket, message}, {listen_socket, room}) do
    message = String.trim_trailing(message)
    room = user_message(user_socket, room, message)
    {:noreply, {listen_socket, room}}
  end

  def handle_info({:tcp_closed, user_socket}, {listen_socket, room}) do
    room = user_disconnected(user_socket, room)
    {:noreply, {listen_socket, room}}
  end

  def handle_info(msg, state) do
    Logger.warn("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Business logic

  defp user_connected(user_socket, room) do
    Logger.info("#{inspect(user_socket)} - User connected")
    room = Room.create_user(room, user_socket)
    send_message(user_socket, @welcome_message)

    room
  end

  defp user_message(user_socket, room, message) do
    user = Room.get_user(room, user_socket)

    case user.status do
      :joined ->
        Logger.info("#{inspect(user_socket)}:#{user.name} - sending message")
        broadcast(room, user_socket, "[#{user.name}] #{message}")
        room

      :naming ->
        if User.valid_name(message) do
          user_joined(user_socket, room, message)
        else
          invalid_name_given(user_socket, room)
        end
    end
  end

  defp user_joined(user_socket, room, name) do
    Logger.info("#{inspect(user_socket)}:#{name} - joined")
    room = Room.user_joined_as(room, user_socket, name)
    broadcast(room, user_socket, "* #{name} has entered the room")
    send_user_list(user_socket, room)
    room
  end

  defp invalid_name_given(user_socket, room) do
    Logger.info("#{inspect(user_socket)} - invalid name given")
    {room, _removed_user} = Room.remove_user(room, user_socket)
    :gen_tcp.close(user_socket)
    room
  end

  defp user_disconnected(user_socket, room) do
    Logger.info("#{inspect(user_socket)} - disconnected")
    {room, removed_user} = Room.remove_user(room, user_socket)
    broadcast_disconnect(room, removed_user)

    room
  end

  defp broadcast_disconnect(room, %User{status: :joined} = removed_user) do
    broadcast(room, "* #{removed_user.name} has left the room")
  end

  defp broadcast_disconnect(_room, _user), do: :ok

  defp send_user_list(user_socket, room) do
    user_list =
      Room.list_joined_users(room)
      |> Map.delete(user_socket)
      |> Enum.map(fn {_id, user} -> user.name end)
      |> Enum.join(", ")

    send_message(user_socket, "* The room contains: #{user_list}")
  end

  # Chat room communication

  defp send_message(user_socket, message) do
    :gen_tcp.send(user_socket, "#{message}\n")
  end

  defp broadcast(%Room{} = room, message) do
    Room.list_joined_users(room)
    |> broadcast(message)
  end

  defp broadcast(users, message) do
    users
    |> Enum.each(fn {user_socket, _} ->
      send_message(user_socket, message)
    end)
  end

  defp broadcast(room, excluding, message) do
    Room.list_joined_users(room)
    |> Map.delete(excluding)
    |> broadcast(message)
  end
end
