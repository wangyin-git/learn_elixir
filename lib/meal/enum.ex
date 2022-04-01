defmodule Meal.Enum do
  use Meal.Delegate,
    to: Enum,
    except: [chunk: 2, chunk: 3, chunk: 4, filter_map: 3, partition: 2, uniq: 2]

    def normalize_index(enumerable, index) when is_integer(index) do
      size = Enum.count(enumerable)
      if index >= 0, do: index, else: index + size
    end

    def normalize_index(enumerable, first..last) do
      normalize_index(enumerable, first)..normalize_index(enumerable, last)
    end

    def enumerable?(element) do
      case Enumerable.impl_for(element) do
        nil -> false
        _ -> true
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
end
