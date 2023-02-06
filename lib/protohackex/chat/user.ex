defmodule Protohackex.Chat.User do
  @valid_codepoints String.codepoints(
                      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    )

  @type t :: %__MODULE__{
          status: :naming | :joined,
          name: nil | String.t()
        }

  defstruct status: :naming, name: nil

  def new() do
    %__MODULE__{}
  end

  @doc """
  ## Examples

  iex> Protohackex.Chat.User.valid_name("Joe")
  true

  iex> Protohackex.Chat.User.valid_name("mary1982")
  true

  iex> Protohackex.Chat.User.valid_name("")
  false

  iex> Protohackex.Chat.User.valid_name("Joe Smith")
  false
  """
  def valid_name(""), do: false

  def valid_name(name) do
    Enum.all?(String.codepoints(name), &(&1 in @valid_codepoints))
  end
end
