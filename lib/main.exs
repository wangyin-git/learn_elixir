import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false


for i <- 1..3, into: Stack.new() do
  i
end
|> p()