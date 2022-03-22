defmodule Meal.Stack do
  alias __MODULE__

  defstruct __list__: []

  def new() do
    %Stack{}
  end

  def new(enumerable) do
    enumerable
    |> Enum.to_list()
    |> then(&%Stack{__list__: &1})
  end

  def to_list(%Stack{__list__: list}) do
    list
  end

  def push(%Stack{} = stack, item) do
    new([item | stack.__list__])
  end

  def pop(%Stack{} = stack) do
    if Enum.empty?(stack.__list__) do
      {:empty, nil, []}
    else
      {item, list} = List.pop_at(stack.__list__, 0)
      {:ok, item, new(list)}
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
