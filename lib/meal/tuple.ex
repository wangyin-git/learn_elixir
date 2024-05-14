defmodule Meal.Tuple do
  use Meal.Delegate, to: Tuple

  def delete_at(tuple, index) when is_tuple(tuple) and is_integer(index) do
    index = Meal.Enum.normalize_index(tuple, index)
    super(tuple, index)
  end

  def insert_at(tuple, index, value) when is_tuple(tuple) and is_integer(index) do
    index =
      cond do
        index >= 0 -> index
        index < 0 -> Meal.Enum.normalize_index(tuple, index) + 1
      end

    super(tuple, index, value)
  end
end

defimpl Enumerable, for: Tuple do
  def count(tuple) do
    {:ok, tuple_size(tuple)}
  end

  def member?(tuple, _element) do
    if tuple_size(tuple) == 0 do
      {:ok, false}
    else
      {:error, __MODULE__}
    end
  end

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(tuple, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(tuple, &1, fun)}
  def reduce({}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(tuple, {:cont, acc}, fun),
    do: reduce(Tuple.delete_at(tuple, 0), fun.(elem(tuple, 0), acc), fun)

  def slice(tuple) do
    size = tuple_size(tuple)

    slice_fun =
      case size do
        0 ->
          fn _, _ -> [] end

        _ ->
          fn start, length
             when start >= 0 and start < size and length >= 1 and start + length <= size ->
            for i <- start..(start + length - 1), into: [] do
              elem(tuple, i)
            end
          end
      end

    {:ok, size, slice_fun}
  end
end

defimpl Collectable, for: Tuple do
  def into(tuple) do
    collector_fun = fn
      acc, {:cont, elem} -> Tuple.append(acc, elem)
      acc, :done -> acc
      _, :halt -> :ok
    end

    {tuple, collector_fun}
  end
end
