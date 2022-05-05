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


case Map.update(%{a: 1, b: 2}, :aa, fn v -> v * 2 end) do
  {:ok, map} -> map
  :error -> "key not found"
end
|> p()
