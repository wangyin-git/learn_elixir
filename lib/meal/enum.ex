defmodule Meal.Enum do
  require Meal

  use Meal.Delegate,
    to: Enum,
    except: [chunk: 2, chunk: 3, chunk: 4, filter_map: 3, partition: 2, uniq: 2]

  def normalize_index(enumerable, index) when is_integer(index) do
    size = Enum.count(enumerable)
    if index >= 0, do: index, else: index + size
  end

  def normalize_range(enumerable, first..last) do
    normalize_index(enumerable, first)..normalize_index(enumerable, last)
  end

  def enumerable?(term) do
    Meal.impl_protocol?(term, Enumerable)
  end

  def random_access?(term) do
    if enumerable?(term) do
      match?({:ok, _, _}, Enumerable.impl_for(term).slice(term))
    else
      raise "can not call on non-enumerable"
    end
  end

  def calc_count?(term) do
    if enumerable?(term) do
      match?({:ok, _}, Enumerable.impl_for(term).count(term))
    else
      raise "can not call on non-enumerable"
    end
  end

  def check_member?(term) do
    if enumerable?(term) do
      match?({:ok, _}, Enumerable.impl_for(term).member?(term, 1))
    else
      raise "can not call on non-enumerable"
    end
  end

  def enumerable_wrap(element) do
    case Enumerable.impl_for(element) do
      nil -> [element]
      _ -> element
    end
  end

  def flatten(deep_enumerable, level \\ -1, tail \\ []) do
    if enumerable?(deep_enumerable) do
      case level do
        n when is_integer(n) and n < 0 ->
          _flatten(deep_enumerable, [])

        0 ->
          Enum.to_list(deep_enumerable)

        n when is_integer(n) and n > 0 ->
          Enum.reduce(1..n, deep_enumerable, fn _, acc ->
            _flat_one_level(acc)
          end)
      end
      |> Enum.concat(enumerable_wrap(tail))
    else
      raise "can not faltten #{deep_enumerable}, it must be enumerable"
    end
  end

  defp _flatten(deep_enumerable, result_list) do
    case Enum.split(deep_enumerable, 1) do
      {[e], rest} ->
        if enumerable?(e) do
          _flatten(_flat_one_level(e) ++ rest, result_list)
        else
          _flatten(rest, [e | result_list])
        end

      {[], []} ->
        Enum.reverse(result_list)
    end
  end

  defp _flat_one_level(enumerable) do
    Enum.flat_map(enumerable, fn e -> enumerable_wrap(e) end)
  end

  def rotate(enumerable, count) when is_integer(count) do
    if !enumerable?(enumerable) do
      raise "cat not rotate non-enumerable"
    end

    case count do
      0 ->
        to_list(enumerable)

      _ ->
        len = Enum.count(enumerable)
        count = rem(count, len)

        cond do
          count == 0 -> to_list(enumerable)
          count > 0 -> slide(enumerable, 0..(count - 1), -1)
          count < 0 -> slide(enumerable, count..-1, 0)
        end
    end
  end

  def values_at(enumerable, list) when is_list(list) do
    if !enumerable?(enumerable), do: raise("can not get values on non-enumerable")

    for idx_or_slice <- list, reduce: [] do
      acc ->
        case idx_or_slice do
          first..last ->
            acc ++ slice(enumerable, first..last)

          idx ->
            acc ++ slice(enumerable, idx..idx)
        end
    end
  end

  def max_n(enumerable, n, sorter \\ &>=/2) when Meal.is_non_neg_integer(n) do
    sort(enumerable, sorter)
    |> take(n)
  end

  def max_n_by(enumerable, n, fun, sorter \\ &>=/2) when Meal.is_non_neg_integer(n) do
    sort_by(enumerable, fun, sorter)
    |> take(n)
  end

  def min_n(enumerable, n, sorter \\ &<=/2) when Meal.is_non_neg_integer(n) do
    sort(enumerable, sorter)
    |> take(n)
  end

  def min_n_by(enumerable, n, fun, sorter \\ &<=/2) when Meal.is_non_neg_integer(n) do
    sort_by(enumerable, fun, sorter)
    |> take(n)
  end
end
