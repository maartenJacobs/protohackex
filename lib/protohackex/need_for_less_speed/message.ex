defmodule Protohackex.NeedForLessSpeed.Message do
  @moduledoc """
  Encode and decode messages to and from the server.

  The nitty-grit of the client-server communication protocol, yet
  surprisingly easy to implement with pattern matching.
  """

  @spec parse_message(binary()) ::
          {:plate, String.t(), non_neg_integer()}
          | {:want_heartbeat, non_neg_integer()}
          | {:camera_id,
             %{road: non_neg_integer(), mile: non_neg_integer(), limit_mph: non_neg_integer()}}
          | {:dispatcher_id, [non_neg_integer()]}
          | :unknown
  def parse_message(payload) do
    case payload do
      <<32::unsigned-integer-8, plate_length::unsigned-integer-8,
        plate::binary-size(plate_length), timestamp::unsigned-integer-32>> ->
        {:plate, plate, timestamp}

      <<64::unsigned-integer-8, interval::unsigned-integer-32>> ->
        {:want_heartbeat, interval}

      <<128::unsigned-integer-8, road::unsigned-integer-16, mile::unsigned-integer-16,
        limit_mph::unsigned-integer-16>> ->
        {:camera_id, %{road: road, mile: mile, limit_mph: limit_mph}}

      <<129::unsigned-integer-8, num_roads::unsigned-integer-8,
        roads::binary-size(num_roads * 2)>> ->
        roads = Protohackex.BitString.chunk_bitstring_every(roads, 2)
        {:dispatcher_id, roads}

      _ ->
        :unknown
    end
  end

  def encode_error(message) do
    <<10::unsigned-integer-8, String.length(message)::unsigned-integer-8, message::binary>>
  end

  def encode_ticket(plate, road, mile1, mile2, timestamp1, timestamp2, speed_mph) do
    <<
      33::unsigned-integer-8,
      String.length(plate)::unsigned-integer-8,
      plate::binary,
      String.length(road)::unsigned-integer-8,
      road::binary,
      mile1::unsigned-integer-16,
      timestamp1::unsigned-integer-32,
      mile2::unsigned-integer-16,
      timestamp2::unsigned-integer-32,
      speed_mph * 100::unsigned-integer-16
    >>
  end

  def encode_heartbeat() do
    <<65::unsigned-integer-8>>
  end
end
