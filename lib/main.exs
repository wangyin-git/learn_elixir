import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false


[1,[2,[3,[4, [5,6]]]]]
|> flatten()
|> p()