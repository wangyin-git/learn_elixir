import Meal, warn: false
alias Meal.Array, warn: false


array = Array.from_enumerable(1..10)
Array.delete_slice(array, 1, -1) |> p