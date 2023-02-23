defmodule Tcp.AsyncServer.ConnectionSupervisor do
  @moduledoc """
  Dynamic TCP connection handler supervisor.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child!(connection_child_spec) do
    {:ok, child} = DynamicSupervisor.start_child(__MODULE__, connection_child_spec)
    child
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
