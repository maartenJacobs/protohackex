defmodule Protohackex.NeedForLessSpeed.Client.Supervisor do
  use DynamicSupervisor

  alias Protohackex.NeedForLessSpeed.Road

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  def start_road(supervisor_pid, road_id) do
    DynamicSupervisor.start_child(supervisor_pid, {Road, road_id})
  end

  # Callbacks

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
