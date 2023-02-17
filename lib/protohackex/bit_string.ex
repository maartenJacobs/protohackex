defmodule Protohackex.BitString do
  def chunk_bitstring_every(bitstring, n_bytes, chunks \\ []) do
    case bitstring do
      <<chunk::binary-size(n_bytes), rest::bits>> ->
        chunk_bitstring_every(rest, n_bytes, [chunk | chunks])

      rest ->
        {Enum.reverse(chunks), rest}
    end
  end
end
