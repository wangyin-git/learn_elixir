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

#Parallel.find_any

Queue.from_enumerable(1..10) |> p()
