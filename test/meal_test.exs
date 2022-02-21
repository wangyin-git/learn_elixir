defmodule MealTest do
  use ExUnit.Case
  doctest Meal

  test "greets the world" do
    assert Meal.hello() == :world
  end
end
