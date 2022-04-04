import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false
alias Meal.Stream, warn: false
alias Meal.Enum, warn: false


Array.from_enumerable(1..10) |> Array.values_at([1,2,3,-1..-2]) |> p()
