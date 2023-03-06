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

  @spec extract_message(t()) :: {t(), Message.message_type()}
  def extract_message(%__MODULE__{} = buffered_socket) do
    {message, buffer_rest} = Message.parse_message(buffered_socket.buffer)
    {struct!(buffered_socket, buffer: buffer_rest), message}
  end

  @spec send_next_message(t()) :: t()
  def send_next_message(%__MODULE__{} = buffered_socket, target_pid \\ self()) do
    {buffered_socket, message} = extract_message(buffered_socket)
    send(target_pid, {:socket_message, message})
    buffered_socket
  end

  @spec extract_all_messages(t()) :: {t(), [Message.message_type()]}
  def extract_all_messages(%__MODULE__{} = buffered_socket) do
    do_extract_all(buffered_socket)
  end

  @doc """
  Extract all messages from the buffer and send them as messages.
  """
  @spec send_all_messages(t()) :: t()
  @spec send_all_messages(t(), pid()) :: t()
  def send_all_messages(%__MODULE__{} = buffered_socket, target_pid \\ self()) do
    {buffered_socket, messages} = extract_all_messages(buffered_socket)
    Enum.each(messages, &send(target_pid, {:socket_message, &1}))
    buffered_socket
  end

  defp do_extract_all(%__MODULE__{} = buffered_socket, messages \\ []) do
    {buffered_socket, message} = extract_message(buffered_socket)

    case message do
      :unknown -> {buffered_socket, Enum.reverse(messages)}
      message -> do_extract_all(buffered_socket, [message | messages])
    end
  end
end
