defmodule Meal.Tuple do
  use Meal.Delegate, to: Tuple

  def delete_at(tuple, index) when is_tuple(tuple) and is_integer(index) do
    index = Meal.Enum.normalize_index(tuple, index)
    super(tuple, index)
  end

  def insert_at(tuple, index, value) when is_tuple(tuple) and is_integer(index) do
    index =
      cond do
        index >= 0 -> index
        index < 0 -> Meal.Enum.normalize_index(tuple, index) + 1
      end

    super(tuple, index, value)
  end
end
