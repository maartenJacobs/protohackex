defmodule Protohackex.NeedForLessSpeed.Heart do
  @moduledoc """
  Manager of client heart beaters.

  Clients can have only one heart beater so the caller is expected to handle error
  case of starting a heart beater.

  Heart beaters automatically stop beating when clients have disconnected, regardless
  of disconnection reason.

  ## Implementation notes

  ### Tracking duplicate heart beaters

  Each client, identified by a socket port, can have only one heart beater. It's a bug
  to have multiple heart beaters for the same socket. Tracking duplicates is implemented
  by using `Registry` with `keys: :unique` and using the socket port as the key.

  Note that `Registry` automatically deregisters heart beaters when the underlying process
  that does the beating dies. No manual deregistration is needed.

  ### 0 interval heart beaters

  An interval of 0ms is a special interval that means the heart beater should not beat.
  But we still need to track duplicate heart beaters, even though no beating is going on.
  This is implemented by starting a monitor server for the socket that does nothing but
  wait for the socket to close. This is silly overhead but the implementation is consistent:
  each interval results in a process registered agains the socket and is automatically
  deregistered.
  """

  use DynamicSupervisor

  alias Protohackex.NeedForLessSpeed.Heart
  alias Protohackex.NeedForLessSpeed.Heart.{BeatServer, MonitorServer}

  # Interface

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @spec start_heartbeat(pid(), any(), integer()) :: :ok | {:error, :already_started}
  def start_heartbeat(heart_pid, socket, interval_ms) do
    server_name = {:via, Registry, {Heart.Registry, socket}}
    child_spec = server_child_spec(socket, interval_ms, server_name)

    DynamicSupervisor.start_child(heart_pid, child_spec)
    |> case do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> {:error, :already_started}
    end
  end

  defp server_child_spec(socket, interval_ms, server_name) do
    if interval_ms > 0 do
      {BeatServer, [socket: socket, interval_ms: interval_ms, name: server_name]}
    else
      {MonitorServer, [socket: socket, name: server_name]}
    end
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
