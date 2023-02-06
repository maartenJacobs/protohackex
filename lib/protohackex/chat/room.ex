defmodule Protohackex.Chat.Room do
  alias Protohackex.Chat.User

  @type user_id :: any()
  @type t :: %__MODULE__{
          users: %{user_id() => User.t()}
        }

  defstruct users: %{}

  def new() do
    %__MODULE__{}
  end

  def get_user(%__MODULE__{} = room, id) do
    Map.fetch!(room.users, id)
  end

  def create_user(%__MODULE__{} = room, id) do
    if Map.has_key?(room.users, id),
      do: raise(RuntimeError, "User #{id} already exists: #{inspect(room.users[id])}")

    struct(room, users: Map.put(room.users, id, User.new()))
  end

  def remove_user(%__MODULE__{} = room, id) do
    if !Map.has_key?(room.users, id), do: raise(RuntimeError, "User #{id} does not exist")

    {struct(room, users: Map.delete(room.users, id)), room.users[id]}
  end

  def user_joined_as(%__MODULE__{} = room, id, name) do
    user = get_user(room, id) |> struct(status: :joined, name: name)
    struct(room, users: Map.put(room.users, id, user))
  end

  def list_joined_users(%__MODULE__{} = room) do
    room.users
    |> Enum.filter(fn {_id, user} -> user.status == :joined end)
    |> Enum.into(%{})
  end
end
