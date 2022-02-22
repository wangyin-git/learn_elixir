import Meal, warn: false
alias Meal.Array, warn: false

#Array.__info__(:functions) |> p

array = Array.new({:default, "xx"})
array = Array.set(0, 1, array)

Array.size(array) |> p