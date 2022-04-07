defmodule Meal.Map do
  use Meal.Delegate, to: Map, except: [map: 2, size: 1]

  def update(%{} = map, key, fun) when is_function(fun, 1) do
    if has_key?(map, key) do
      update!(map, key, fun)
    else
      map
    end
  end
end
