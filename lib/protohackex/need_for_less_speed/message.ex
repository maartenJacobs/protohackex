defmodule Protohackex.NeedForLessSpeed.Message do
  @moduledoc """
  Encode and decode messages to and from the server.

  The nitty-grit of the client-server communication protocol, yet
  surprisingly easy to implement with pattern matching.
  """

  alias Protohackex.NeedForLessSpeed.Violation
  alias Protohackex.NeedForLessSpeed.Road

  require Logger

  @valid_message_types [
    16,
    32,
    33,
    64,
    65,
    128,
    129
  ]

  @type message_type ::
          {:plate, String.t(), non_neg_integer()}
          | {:want_heartbeat, non_neg_integer()}
          | {:camera_id, Road.camera()}
          | {:dispatcher_id, [non_neg_integer()]}
          | :invalid_message
          | :unknown

  @spec parse_message(binary()) :: {message_type(), binary()}
  def parse_message(payload) do
    case payload do
      <<32::unsigned-integer-8, plate_length::unsigned-integer-8,
        plate::binary-size(plate_length), timestamp::unsigned-integer-32, rest::binary>> ->
        {{:plate, plate, timestamp}, rest}

      <<64::unsigned-integer-8, interval_deciseconds::unsigned-integer-32, rest::binary>> ->
        {{:want_heartbeat, interval_deciseconds * 100}, rest}

      <<128::unsigned-integer-8, road::unsigned-integer-16, mile::unsigned-integer-16,
        limit_mph::unsigned-integer-16, rest::binary>> ->
        {{:camera_id, %{road: road, mile: mile, limit_mph: limit_mph}}, rest}

      <<129::unsigned-integer-8, num_roads::unsigned-integer-8, roads::binary-size(num_roads * 2),
        rest::binary>> ->
        roads = decode_roads(roads)
        {{:dispatcher_id, roads}, rest}

      # Clients may also send messages that are supposed to come from the server.
      # But these should be considered invalid: clients are not servers.

      <<16::unsigned-integer-8, error_length::unsigned-integer-8,
        _error_msg::binary-size(error_length), rest::binary>> ->
        {:invalid_message, rest}

      <<
        33::unsigned-integer-8,
        plate_length::unsigned-integer-8,
        _plate::binary-size(plate_length),
        _road::unsigned-integer-16,
        _mile1::unsigned-integer-16,
        _timestamp1::unsigned-integer-32,
        _mile2::unsigned-integer-16,
        _timestamp2::unsigned-integer-32,
        _speed::unsigned-integer-16,
        rest::binary
      >> ->
        {:invalid_message, rest}

      <<65::unsigned-integer-8, rest::binary>> ->
        {:invalid_message, rest}

      <<message_code::unsigned-integer-8, rest::binary>> ->
        # The message may be in a state of being sent, e.g. byte by byte instead of a whole message.
        # Fortunately for the message is a single byte so no matter what we should be receiving a
        # byte that matches a known message type.
        if message_code in @valid_message_types do
          # Continue receiving, basically.
          {:unknown, payload}
        else
          {:invalid_message, rest}
        end

      _ ->
        # This will actually just be an empty message. In a real system we would refactor
        # this to prevent empty messages.
        {:unknown, payload}
    end
  end

  def encode_error(message) do
    <<16::unsigned-integer-8, String.length(message)::unsigned-integer-8, message::binary>>
  end

  def encode_ticket(%Violation{} = violation) do
    encode_ticket(
      violation.plate,
      violation.road,
      violation.mile1,
      violation.mile2,
      violation.timestamp1,
      violation.timestamp2,
      violation.speed_mph
    )
  end

  def encode_ticket(plate, road, mile1, mile2, timestamp1, timestamp2, speed_mph) do
    <<
      33::unsigned-integer-8,
      String.length(plate)::unsigned-integer-8,
      plate::binary,
      road::unsigned-integer-16,
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

  defp decode_roads(roads) do
    {road_chunks, ""} = Protohackex.BitString.chunk_bitstring_every(roads, 2)

    for road_chunk <- road_chunks do
      <<road_id::unsigned-integer-16>> = road_chunk
      road_id
    end
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

  def encode_plate(plate, timestamp) do
    <<32::unsigned-integer-8, String.length(plate)::unsigned-integer-8,
      plate::binary-size(String.length(plate)), timestamp::unsigned-integer-32>>
  end

  def encode_want_heartbeat(interval_ms) do
    <<64::unsigned-integer-8, interval_ms |> div(100)::unsigned-integer-32>>
  end
end
