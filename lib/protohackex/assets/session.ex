defmodule Protohackex.Assets.Session do
  @moduledoc """
  ## Examples

    iex> Protohackex.Assets.Session.new() \
         |> Protohackex.Assets.Session.insert(12345, 101) \
         |> Protohackex.Assets.Session.insert(12346, 102) \
         |> Protohackex.Assets.Session.insert(12347, 100) \
         |> Protohackex.Assets.Session.insert(40960, 5) \
         |> Protohackex.Assets.Session.query(12288, 16384) \
         |> elem(1)
    101

    iex> Protohackex.Assets.Session.new() \
         |> Protohackex.Assets.Session.query(12288, 16384) \
         |> elem(1)
    0

    iex> Protohackex.Assets.Session.new() \
         |> Protohackex.Assets.Session.insert(12345, 101) \
         |> Protohackex.Assets.Session.insert(12346, 102) \
         |> Protohackex.Assets.Session.query(12346, 12345) \
         |> elem(1)
    0
  """

  defstruct [:entries]

  def new() do
    %__MODULE__{entries: []}
  end

  def insert(%__MODULE__{entries: entries} = session, timestamp, price) do
    new_entries = [{timestamp, price} | entries]
    struct(session, entries: new_entries)
  end

  def query(%__MODULE__{entries: entries} = session, mintimestamp, maxtimestamp) do
    %{total: total, count: count} =
      entries
      |> Enum.reduce(
        %{total: 0, count: 0},
        fn {timestamp, price}, %{total: total, count: count} = acc ->
          if mintimestamp <= timestamp && maxtimestamp >= timestamp do
            %{total: total + price, count: count + 1}
          else
            acc
          end
        end
      )

    mean =
      if count == 0 do
        0
      else
        div(total, count)
      end

    {session, mean}
  end
end
