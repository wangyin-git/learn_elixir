import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false
alias Meal.Stream, warn: false
alias Meal.Enum, warn: false

Stream.combination(5..1//-1, 2) |> Enum.to_list() |> p()
