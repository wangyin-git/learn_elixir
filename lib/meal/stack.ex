defmodule Meal.Stack do
  alias __MODULE__

  defstruct __list__: [], size: 0

  def new() do
    %Stack{}
  end

  def new(enumerable) do
    enumerable
    |> Enum.to_list()
    |> then(&_new(&1, length(&1)))
  end

  defp _new(list, size) do
    %Stack{__list__: list, size: size}
  end

  def to_list(%Stack{__list__: list}) do
    list
  end

  def push(%Stack{size: size} = stack, item) do
    _new([item | stack.__list__], size + 1)
  end

  def pop(%Stack{size: size} = stack) do
    if Enum.empty?(stack.__list__) do
      {:empty, nil, new()}
    else
      {item, list} = List.pop_at(stack.__list__, 0)
      {:ok, item, _new(list, size - 1)}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Stack{} = stack, opts) do
      concat(["##{@for}", to_doc(stack.__list__, opts)])
    end
  end

  defimpl Collectable do
    def into(%Stack{} = stack) do
      collector_fun = fn
        acc, {:cont, elem} -> Stack.push(acc, elem)
        acc, :done -> acc
        _, :halt -> :ok
      end

      {stack, collector_fun}
    end
  end
end
