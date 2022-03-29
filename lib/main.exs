import Meal, warn: false
alias Meal.Array, warn: false
alias Meal.String, warn: false
alias Meal.Stack, warn: false


Meal.block(:hi) do
  block do
    break(123, label: :hi)
  end
end

|> p()
