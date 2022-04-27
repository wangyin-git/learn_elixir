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

queue = Queue.new()

Enum.random_access?(queue) |> p()
Enum.calc_count?(queue) |> p()
Enum.check_member?(queue) |> p()
