defmodule Protohackex.NeedForLessSpeed.Heart.BeatServer do
  @moduledoc false

  alias Protohackex.NeedForLessSpeed.Message

  use GenServer, restart: :transient

  require Logger

  defstruct [:socket, :interval_ms]

  # Interface

  def start_link(opts) do
    socket = Keyword.fetch!(opts, :socket)
    interval_ms = Keyword.fetch!(opts, :interval_ms)

    server_options = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, {socket, interval_ms}, server_options)
  end

  # GenServer callbacks

  def init({socket, interval_ms}) do
    Logger.info("Start heat beat at #{interval_ms}ms", socket: socket)
    Process.send_after(self(), :beat, interval_ms)
    {:ok, %__MODULE__{socket: socket, interval_ms: interval_ms}}
  end

  def handle_info(:beat, %__MODULE__{} = heart) do
    case :gen_tcp.send(heart.socket, Message.encode_heartbeat()) do
      :ok ->
        Process.send_after(self(), :beat, heart.interval_ms)
        {:noreply, heart}

      {:error, :closed} ->
        Logger.info("Stop heart beat", socket: heart.socket)
        {:stop, :normal, heart}
    end
  end
end
