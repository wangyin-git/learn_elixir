defmodule Meal.Iterator do
  @enforce_keys [:iterable]
  defstruct [:iterable]

  def new(iterable) do
    unless Meal.impl_protocol?(iterable, Meal.Iterable) do
      raise ArgumentError,
            "Argument for Meal.Iterator.new/1 must implement Meal.Iterable protocol"
    end

    %Meal.Iterator{iterable: iterable}
  end

  def next(%Meal.Iterator{iterable: iterable}) do
    Meal.Iterable.next(iterable)
  end

  def peek(%Meal.Iterator{iterable: iterable}) do
    Meal.Iterable.peek(iterable)
  end

  def end?(%Meal.Iterator{} = iter) do
    peek(iter) == :end
  end
end

defimpl Enumerable, for: Meal.Iterator do
  alias Meal.Iterator

  def count(%Iterator{} = iter) do
    if Iterator.end?(iter) do
      {:ok, 0}
    else
      {:error, __MODULE__}
    end
  end

  def member?(%Iterator{} = iter, _element) do
    if Iterator.end?(iter) do
      {:ok, false}
    else
      {:error, __MODULE__}
    end
  end

  def slice(%Iterator{} = iter) do
    if Iterator.end?(iter) do
      {:ok, 0, fn _, _ -> [] end}
    else
      {:error, __MODULE__}
    end
  end

  def reduce(_iter, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(iter, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iter, &1, fun)}

  def reduce(%Iterator{} = iter, {:cont, acc}, fun) do
    if Iterator.end?(iter) do
      {:done, acc}
    else
      {:ok, head, iter} = Iterator.next(iter)
      reduce(iter, fun.(head, acc), fun)
    end
  end
end

defprotocol Meal.Iterable do
  @spec next(any()) :: :end | {:ok, any(), %Meal.Iterator{}}
  def next(iterable)

  @spec peek(any()) :: :end | {:ok, any()}
  def peek(iterable)
end

defimpl Meal.Iterable, for: List do
  @spec next(list()) :: :end | {:ok, any(), %Meal.Iterator{iterable: list()}}
  def next(list) do
    if match?([], list) do
      :end
    else
      {:ok, hd(list), Meal.Iterator.new(tl(list))}
    end
  end

  @spec peek(list()) :: :end | {:ok, any()}
  def peek(list) do
    if match?([], list) do
      :end
    else
      {:ok, hd(list)}
    end
  end
end

defimpl Meal.Iterable, for: Map do
  @spec next(map()) :: :end | {:ok, {any(), any()}, %Meal.Iterator{iterable: map()}}
  def next(map) do
    if map_size(map) == 0 do
      :end
    else
      {k, v} = Enum.at(map, 0)
      {:ok, {k, v}, Meal.Iterator.new(Map.drop(map, [k]))}
    end
  end

  @spec peek(map()) :: :end | {:ok, {any(), any()}}
  def peek(map) do
    if map_size(map) == 0 do
      :end
    else
      {:ok, Enum.at(map, 0)}
    end
  end
end

defimpl Meal.Iterable, for: MapSet do
  @spec next(%MapSet{}) :: :end | {:ok, any(), %Meal.Iterator{iterable: %MapSet{}}}
  def next(set) do
    if Enum.empty?(set) do
      :end
    else
      v = Enum.at(set, 0)
      {:ok, v, Meal.Iterator.new(MapSet.delete(set, v))}
    end
  end

  @spec peek(MapSet.t()) :: :end | {:ok, any()}
  def peek(set) do
    if Enum.empty?(set) do
      :end
    else
      {:ok, Enum.at(set, 0)}
    end
  end
end

defimpl Meal.Iterable, for: Tuple do
  @spec next(tuple()) :: :end | {:ok, any(), %Meal.Iterator{iterable: tuple()}}
  def next(tuple) do
    if tuple_size(tuple) == 0 do
      :end
    else
      {:ok, elem(tuple, 0), Meal.Iterator.new(Tuple.delete_at(tuple, 0))}
    end
  end

  @spec peek(tuple()) :: :end | {:ok, any()}
  def peek(tuple) do
    if tuple_size(tuple) == 0 do
      :end
    else
      {:ok, elem(tuple, 0)}
    end
  end
end

defimpl Meal.Iterable, for: Range do
  @spec next(Range.t()) :: :end | {:ok, any(), %Meal.Iterator{iterable: Range.t()}}
  def next(range) when is_struct(range, Range) do
    if Enum.empty?(range) do
      :end
    else
      {:ok, Enum.at(range, 0), Meal.Iterator.new(Range.split(range, 1) |> elem(1))}
    end
  end

  @spec peek(Range.t()) :: :end | {:ok, any()}
  def peek(range) when is_struct(range, Range) do
    if Enum.empty?(range) do
      :end
    else
      {:ok, Enum.at(range, 0)}
    end
  end
end
