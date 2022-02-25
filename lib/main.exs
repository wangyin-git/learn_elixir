import Meal, warn: false
alias Meal.Array, warn: false


array = Array.from_enumerable(1..10)
array[2..-1] |> p