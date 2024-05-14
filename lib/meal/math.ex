defmodule Meal.Math do
  require Meal
  use Meal.Delegate, to: :math

  def fact(0), do: 1
  def fact(n) when is_integer(n) and n > 0, do: _fact(n, n - 1)

  defp _fact(acc, 0), do: acc
  defp _fact(acc, n), do: _fact(acc * n, n - 1)
end
