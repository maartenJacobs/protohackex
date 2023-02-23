defmodule Protohackex.NeedForLessSpeed.BufferedSocket do
  alias Protohackex.NeedForLessSpeed.Message

  defstruct [:socket, :buffer]

  def new(socket) do
    %__MODULE__{socket: socket, buffer: <<>>}
  end

  def add_payload(%__MODULE__{} = buffered_socket, payload) do
    struct!(buffered_socket, buffer: buffered_socket.buffer <> payload)
  end

  def extract_message(%__MODULE__{} = buffered_socket) do
    {message, buffer_rest} = Message.parse_message(buffered_socket.buffer)
    {struct!(buffered_socket, buffer: buffer_rest), message}
  end
end
