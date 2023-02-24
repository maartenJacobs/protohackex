defmodule Protohackex.NeedForLessSpeed.Message do
  @moduledoc """
  Encode and decode messages to and from the server.

  The nitty-grit of the client-server communication protocol, yet
  surprisingly easy to implement with pattern matching.
  """

  alias Protohackex.NeedForLessSpeed.Road

  @type message_type ::
          {:plate, String.t(), non_neg_integer()}
          | {:want_heartbeat, non_neg_integer()}
          | {:camera_id, Road.camera()}
          | {:dispatcher_id, [non_neg_integer()]}
          | :unknown

  @spec parse_message(binary()) :: {message_type(), binary()}
  def parse_message(payload) do
    case payload do
      <<32::unsigned-integer-8, plate_length::unsigned-integer-8,
        plate::binary-size(plate_length), timestamp::unsigned-integer-32, rest::binary>> ->
        {{:plate, plate, timestamp}, rest}

      <<64::unsigned-integer-8, interval::unsigned-integer-32, rest::binary>> ->
        {{:want_heartbeat, interval}, rest}

      <<128::unsigned-integer-8, road::unsigned-integer-16, mile::unsigned-integer-16,
        limit_mph::unsigned-integer-16, rest::binary>> ->
        {{:camera_id, %{road: road, mile: mile, limit_mph: limit_mph}}, rest}

      <<129::unsigned-integer-8, num_roads::unsigned-integer-8, roads::binary-size(num_roads * 2),
        rest::binary>> ->
        roads = Protohackex.BitString.chunk_bitstring_every(roads, 2)
        {{:dispatcher_id, roads}, rest}

      _ ->
        {:unknown, payload}
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

  # ===
  # Encoding and decoding for testing
  # ===

  def encode_camera_id(road_id, mile, limit_mph) do
    <<128::unsigned-integer-8, road_id::unsigned-integer-16, mile::unsigned-integer-16,
      limit_mph::unsigned-integer-16>>
  end

  def encode_dispatcher_id(roads) do
    rest =
      for road <- roads, reduce: <<>> do
        rest ->
          rest <> <<road::unsigned-integer-16>>
      end

    <<129::unsigned-integer-8, length(roads)::unsigned-integer-8>> <> rest
  end
end
