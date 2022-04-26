defmodule Meal.Stream do
  require Meal
  alias Meal.Array

  use Meal.Delegate, to: Stream, except: [chunk: 2, chunk: 3, chunk: 4, filter_map: 3, uniq: 2]

  def combination(enumerable, r) when is_integer(r) do
    if Meal.Enum.enumerable?(enumerable) do
      count = Enum.count(enumerable)

      _combination(count, r)
      |> Stream.map(fn comb -> Enum.map(comb, &Enum.at(enumerable, &1)) end)
    else
      raise "can not get combination from non-enumerable"
    end
  end

  defp _combination(n, r) do
    cond do
      r < 0 || r > n ->
        Stream.concat([])

      r == 0 ->
        Stream.concat([[]], [])

      r > 0 ->
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
    if Meal.Enum.enumerable?(enumerable) do
      count = Enum.count(enumerable)

      _repeated_combination(count, r)
      |> Stream.map(fn comb -> Enum.map(comb, &Enum.at(enumerable, &1)) end)
    else
      raise "can not get repeated combination from non-enumerable"
    end
  end

  defp _repeated_combination(n, r) do
    cond do
      r < 0 ->
        Stream.concat([])

      r == 0 ->
        Stream.concat([[]], [])

      n == 0 ->
        Stream.concat([])

      r > 0 ->
        start_comb = Array.from_list(List.duplicate(0, r))
        end_comb = Array.from_list(List.duplicate(n - 1, r))

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

  def permutation(enumerable, r) when is_integer(r) do
    if Meal.Enum.enumerable?(enumerable) do
      count = Enum.count(enumerable)

      _permutation(count, r)
      |> Stream.map(fn perm -> Enum.map(perm, &Enum.at(enumerable, &1)) end)
    else
      raise "can not get permutation from non-enumerable"
    end
  end

  defp _permutation(n, r) do
    cond do
      r < 0 || r > n ->
        Stream.concat([])

      r == 0 ->
        Stream.concat([[]], [])

      r == 1 ->
        Stream.map(0..(n - 1), fn e -> [e] end)

      r > 1 ->
        Enum.reduce(
          2..(r - 1)//1,
          _permutation_product(Stream.map(0..(n - 1), &{[&1], MapSet.new([&1])}), 0..(n - 1)),
          fn _, acc ->
            _permutation_product(acc, 0..(n - 1))
          end
        )
        |> Stream.map(fn {perm, _} -> perm end)
    end
  end

  defp _permutation_product(enumerable1, enumerable2) do
    Stream.transform(enumerable1, enumerable2, fn {list, set}, acc ->
      {Stream.flat_map(acc, fn e2 ->
         if MapSet.member?(set, e2) do
           []
         else
           [{list ++ [e2], MapSet.put(set, e2)}]
         end
       end), acc}
    end)
  end

  def repeated_permutation(enumerable, r) when is_integer(r) do
    if Meal.Enum.enumerable?(enumerable) do
      cond do
        r < 0 ->
          Stream.concat([])

        r == 0 ->
          Stream.concat([[]], [])

        Enum.empty?(enumerable) ->
          Stream.concat([])

        r == 1 ->
          Stream.map(enumerable, fn e -> [e] end)

        r > 1 ->
          Enum.reduce(2..(r - 1)//1, cartesian_product(enumerable, enumerable), fn _, acc ->
            cartesian_product(acc, enumerable)
            |> Stream.map(&List.flatten(&1))
          end)
      end
    else
      raise "can not get repeated permutation from non-enumerable"
    end
  end

  def cartesian_product(enumerable1, enumerable2) do
    Stream.transform(enumerable1, enumerable2, fn e1, acc ->
      {Stream.map(acc, fn e2 -> [e1, e2] end), acc}
    end)
  end

  def cycle(enumerable, count) when Meal.is_non_neg_integer(count) do
    if Meal.Enum.enumerable?(enumerable) do
      Stream.unfold(count, fn
        0 -> nil
        count -> {enumerable, count - 1}
      end)
      |> Stream.flat_map(& &1)
    else
      raise "can not cycle on non-enumerable"
    end
  end

  def max_n(enumerable, n, sorter \\ &>=/2) when Meal.is_non_neg_integer(n) do
    Enum.sort(enumerable, sorter)
    |> take(n)
  end

  def max_n_by(enumerable, n, fun, sorter \\ &>=/2) when Meal.is_non_neg_integer(n) do
    Enum.sort_by(enumerable, fun, sorter)
    |> take(n)
  end

  def min_n(enumerable, n, sorter \\ &<=/2) when Meal.is_non_neg_integer(n) do
    Enum.sort(enumerable, sorter)
    |> take(n)
  end

  def min_n_by(enumerable, n, fun, sorter \\ &<=/2) when Meal.is_non_neg_integer(n) do
    Enum.sort_by(enumerable, fun, sorter)
    |> take(n)
  end
end
