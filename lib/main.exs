import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false
alias Meal.Stream, warn: false
alias Meal.Enum, warn: false


%{a: 1, b: 2} |> Enum.values_at([1,2,3, -2..-1]) |> p()
