defmodule Protohackex.EchoServer do
  @moduledoc """
  Sends received TCP packet back to origin socket.
  """

  use Task

  def start_link(socket) do
    Task.start_link(__MODULE__, :run, [socket])
  end

  def run(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        :gen_tcp.send(socket, packet)
        run(socket)

      {:error, _reason} ->
        :ok
    end
  end
end
