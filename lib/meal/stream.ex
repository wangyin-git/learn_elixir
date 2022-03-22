defmodule Meal.Stream do
  alias Meal.Array

  def combination(enumerable, r) when is_integer(r) do
    count = Enum.count(enumerable)

    _combination(count, r)
    |> Stream.map(fn comb -> Enum.map(comb, &Enum.at(enumerable, &1)) end)
  end

  defp _combination(n, r) do
    cond do
      r < 0 || r > n ->
        Stream.concat([])

      r == 0 ->
        Stream.concat([[]], [])

      r > 0 && r <= n ->
        start_comb = Array.from_enumerable(0..(r - 1))
        end_comb = Array.from_enumerable((n - r)..(n - 1))

        Stream.unfold(
          :start,
          fn
            :start ->
              {start_comb, start_comb}

            ^end_comb ->
              nil

            prev_comb ->
              Enum.reduce_while(
                -1..-r,
                prev_comb,
                fn idx, comb ->
                  add_one = comb[idx] + 1

                  if add_one <= n + idx do
                    next_comb = Array.replace_slice(comb, idx, -1, add_one..(add_one - idx - 1))
                    {:halt, next_comb}
                  else
                    {:cont, comb}
                  end
                end
              )
              |> then(&{&1, &1})
          end
        )
    end
  end

  def repeated_combination(enumerable, r) when is_integer(r) do
    count = Enum.count(enumerable)

    _repeated_combination(count, r)
    |> Stream.map(fn comb -> Enum.map(comb, &Enum.at(enumerable, &1)) end)
  end

  defp _repeated_combination(n, r) do
    cond do
      r < 0 ->
        Stream.concat([])

      r == 0 ->
        Stream.concat([[]], [])

      r > 0 ->
        start_comb = Array.from_list(List.duplicate(0, r))
        end_comb = Array.from_enumerable(List.duplicate(n - 1, r))

        Stream.unfold(
          :start,
          fn
            :start ->
              {start_comb, start_comb}

            ^end_comb ->
              nil

            prev_comb ->
              Enum.reduce_while(
                -1..-r,
                prev_comb,
                fn idx, comb ->
                  add_one = comb[idx] + 1

                  if add_one <= n - 1 do
                    next_comb = Array.replace_slice(comb, idx, -1, List.duplicate(add_one, -idx))
                    {:halt, next_comb}
                  else
                    {:cont, comb}
                  end
                end
              )
              |> then(&{&1, &1})
          end
        )
    end
  end

  def _permutation_all(n) do
  end
end
