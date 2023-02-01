defmodule Protohackex.PrimeServer do
  @moduledoc """
  Prime server answers requests about numbers.
  """

  use Task

  require Logger

  alias Protohackex.Number

  # Server configuration

  def packet_mode(), do: :line

  # Task callbacks

  def start_link(socket) do
    Task.start_link(__MODULE__, :run, [socket])
  end

  def run(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, payload} ->
        # The server has been configured to receive a packet when a newline is detected but these
        # newlines are not stripped and multiple requests may be received. This is not related to
        # business logic so we deal with the request format here.
        packets =
          payload
          |> String.trim()
          |> String.split("\n")

        for packet <- packets do
          process_packet(socket, packet)
        end

        run(socket)

      {:error, _reason} ->
        :ok
    end
  end

  # Business logic

  defp process_packet(socket, packet) do
    case parse_request(packet) do
      {:ok, request} ->
        process_request(socket, request)

      {:error, _} ->
        Logger.info("Received malformed request #{packet}")
        :gen_tcp.send(socket, "malformed request\n")
    end
  end

  def parse_request(packet) do
    with {:ok, request} <- Jason.decode(packet),
         {:ok, %{"number" => number}} <- validate_message_structure(request),
         {:ok, _number} <- validate_number(number) do
      {:ok, request}
    else
      {:error, _} -> {:error, :malformed}
    end
  end

  defp validate_message_structure(%{"method" => "isPrime", "number" => _number} = request),
    do: {:ok, request}

  defp validate_message_structure(_request), do: {:error, :unknown_structure}

  defp validate_number(number) when is_number(number), do: {:ok, number}
  defp validate_number(_number), do: {:error, :not_a_number}

  defp process_request(socket, %{"method" => "isPrime", "number" => number}) do
    Logger.info("Request from #{inspect(socket)} #{number} received")

    prime? = Number.prime?(number)

    answer =
      %{
        method: "isPrime",
        prime: prime?
      }
      |> Jason.encode!()
      |> Kernel.<>("\n")

    Logger.info("Request from #{inspect(socket)} for #{number} answered -- #{prime?}")

    :gen_tcp.send(socket, answer)
  end
end
