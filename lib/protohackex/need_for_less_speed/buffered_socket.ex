defmodule Protohackex.NeedForLessSpeed.BufferedSocket do
  alias Protohackex.NeedForLessSpeed.Message

  @type t :: %__MODULE__{socket: any(), buffer: binary()}
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

  def extract_all_messages(%__MODULE__{} = buffered_socket) do
    do_extract_all(buffered_socket)
  end

  defp do_extract_all(%__MODULE__{} = buffered_socket, messages \\ []) do
    {buffered_socket, message} = extract_message(buffered_socket)

    case message do
      :unknown -> {buffered_socket, Enum.reverse(messages)}
      message -> do_extract_all(buffered_socket, [message | messages])
    end
  end
end
