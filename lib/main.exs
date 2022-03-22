import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false

[1,[2,[3,[4, [5,[[[6]]]]]]]]
|> flatten(5)
|> p()

List.foldl([1,2,3], 1, fn e, acc -> e + acc end)
|> p()
