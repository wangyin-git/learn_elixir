import Meal, warn: false
alias Meal.Array, warn: false
#alias Meal.String, warn: false

Meal.Stream.combination(1..10, 3)
|> Enum.to_list()
|> p()
