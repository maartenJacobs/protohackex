defmodule Protohackex.AssetServer do
  @moduledoc """
  Asset server privately tracks the value of your assets.
  """

  use Task

  require Logger

  alias Protohackex.Assets.Session

  # Task callbacks and network parsing

  def start_link(socket) do
    Task.start_link(__MODULE__, :run, [socket, <<>>, Session.new()])
  end

  def run(socket, buffer, %Session{} = session) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, payload} ->
        buffer = buffer <> payload
        {requests, buffer} = chunk_bitstring_every(buffer, 9)

        session = process(socket, session, requests)

        run(socket, buffer, session)

      {:error, _reason} ->
        :ok
    end
  end

  defp chunk_bitstring_every(bitstring, n_bytes, chunks \\ []) do
    case bitstring do
      <<chunk::binary-size(n_bytes), rest::bits>> ->
        chunk_bitstring_every(rest, n_bytes, [chunk | chunks])

      rest ->
        {Enum.reverse(chunks), rest}
    end
  end

  # Business logic

  defp process(socket, session, requests) when is_list(requests) do
    for request <- requests, reduce: session do
      session ->
        process(socket, session, request)
    end
  end

  defp process(socket, session, <<command, value1::signed-integer-32, value2::signed-integer-32>>) do
    {time, session} =
      :timer.tc(fn ->
        case {command, value1, value2} do
          {?Q, mintimestamp, maxtimestamp} ->
            {session, result} = Session.query(session, mintimestamp, maxtimestamp)
            Logger.info("Responding to #{mintimestamp} and #{maxtimestamp} with #{result}.")
            response = <<result::signed-integer-32>>
            :gen_tcp.send(socket, response)

            session

          {?I, timestamp, price} ->
            Session.insert(session, timestamp, price)

          other ->
            Logger.info("Unknown request #{inspect(other)}. Skipping.")
            session
        end
      end)

    Logger.info("Processed request in #{time / 1_000_000}s.")
    session
  end
end
