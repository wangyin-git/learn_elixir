import Meal, warn: false
alias Meal.Array, warn: false

array = Array.from_list([1,2,3,4,5,6])

get_and_update_in(array, [1..2], fn value -> {value, 999} end) |> p