defmodule Protohackex.NeedForLessSpeed.Heart do
  @moduledoc """
  Manager of client heart beaters.

  Clients can have only one heart beater so the caller is expected to handle error
  case of starting a heart beater.

  Heart beaters automatically stop beating when clients have disconnected, regardless
  of disconnection reason.
  """

  use DynamicSupervisor

  alias Protohackex.NeedForLessSpeed.Heart
  alias Protohackex.NeedForLessSpeed.Heart.BeatServer

  # Interface

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @spec start_heartbeat(pid(), any(), integer()) :: :ok | {:error, :already_started}
  def start_heartbeat(heart_pid, socket, interval_ms) do
    beat_server_name = {:via, Registry, {Heart.Registry, socket}}

    DynamicSupervisor.start_child(
      heart_pid,
      {BeatServer, [socket: socket, interval_ms: interval_ms, name: beat_server_name]}
    )
    |> case do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> {:error, :already_started}
    end
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
