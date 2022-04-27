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

queue = Queue.from_enumerable(1..3)

Enum.random_access?({1}) |> p()
Enum.calc_count?({1}) |> p()
Enum.check_member?({1}) |> p()
