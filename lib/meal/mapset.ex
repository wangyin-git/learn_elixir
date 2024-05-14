defmodule Meal.MapSet do
  use Meal.Delegate, to: MapSet

  def strict_subset?(map_set1, map_set2) do
    size(map_set1) < size(map_set2) && subset?(map_set1, map_set2)
  end
end
