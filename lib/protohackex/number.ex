defmodule Protohackex.Number do
  # Prime calculation from https://github.com/mdoza/elixir_math/blob/master/lib/elixir_math/prime_generator.ex#L31

  def prime?(n) when is_float(n), do: false

  def prime?(2), do: true
  def prime?(n) when n < 2 or rem(n, 2) == 0, do: false
  def prime?(n), do: prime?(n, 3)

  defp prime?(n, x) when n < x * x, do: true
  defp prime?(n, x) when rem(n, x) == 0, do: false
  defp prime?(n, x), do: prime?(n, x + 2)
end
