import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false
alias Meal.Stream, warn: false
alias Meal.Enum, warn: false
alias Meal.Map, warn: false
alias Meal.Tuple, warn: false
alias Meal.Parallel, warn: false
alias Meal.Queue, warn: false

Stream.repeated_combination(1..3, 10) |> Enum.take(10) |> p()
