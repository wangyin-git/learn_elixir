defmodule Meal.Array do
  @moduledoc false
  @behaviour Access

  require Meal
  alias __MODULE__

  defstruct [__array__: :array.new()]

  def new() do
    %Array{}
  end

  def new(size) when Meal.is_non_neg_integer(size) do
    %Array{__array__: :array.new(size: size, fixed: false)}
  end

  def new(size: size, default: default_value) when Meal.is_non_neg_integer(size) do
    %Array{__array__: :array.new(size: size, default: default_value, fixed: false)}
  end

  def from_erlang_array(array) do
    if :array.is_array(array) do
      %Array{__array__: array}
    else
      raise "can not create #{__MODULE__} from #{array}"
    end
  end

  def from_list(list) when is_list(list) do
    :array.from_list(list)
    |> from_erlang_array()
  end

  def from_list(list, default) when is_list(list) do
    :array.from_list(list, default)
    |> from_erlang_array()
  end

  def from_index_paris(index_pairs) when is_list(index_pairs) do
    :array.from_orddict(Enum.map(index_pairs, &{elem(&1, 1), elem(&1, 0)}))
    |> from_erlang_array()
  end

  def from_index_paris(index_pairs, default) when is_list(index_pairs) do
    :array.from_orddict(Enum.map(index_pairs, &{elem(&1, 1), elem(&1, 0)}), default)
    |> from_erlang_array()
  end

  def to_list(%Array{} = array) do
    :array.to_list(array.__array__)
  end

  def sparse_to_list(%Array{} = array) do
    :array.sparse_to_list(array.__array__)
  end

  def with_index(%Array{} = array) do
    :array.to_orddict(array.__array__)
    |> Enum.map(&{elem(&1, 1), elem(&1, 0)})
  end

  def sparse_with_index(%Array{} = array) do
    :array.sparse_to_orddict(array.__array__)
    |> Enum.map(&{elem(&1, 1), elem(&1, 0)})
  end

  def default(%Array{} = array) do
    :array.default(array.__array__)
  end

  def size(%Array{} = array) do
    :array.size(array.__array__)
  end

  def sparse_size(%Array{} = array) do
    :array.sparse_size(array.__array__)
  end

  def get(%Array{} = array, index) when is_integer(index) do
    get(array, index, default(array))
  end

  def get(%Array{} = array, index, default) when is_integer(index) do
    index = Meal.normalize_index(array, index)
    if index < 0 || index >= size(array) do
      default
    else
      :array.get(index, array.__array__)
    end
  end

  def slice(%Array{} = array, first..last) do
    Enum.slice(array, first..last)
    |> from_list()
  end

  def slice(%Array{} = array, start_index, amount) when is_integer(start_index) and Meal.is_non_neg_integer(amount) do
    Enum.slice(array, start_index, amount)
    |> from_list()
  end

  def set(%Array{} = array, index, value) when is_integer(index) do
    index = Meal.normalize_index(array, index)
    :array.set(index, value, array.__array__)
    |> from_erlang_array()
  end

  def insert_at(%Array{} = array, index, value) when is_integer(index) do
    to_list(array)
    |> List.insert_at(index, value)
    |> from_list()
  end

  def delete_at(%Array{} = array, index) when is_integer(index) do
    to_list(array)
    |> List.delete_at(index)
    |> from_list()
  end

  def delete_slice(%Array{} = array, first..last) do
    replace_slice(array, first..last, [])
  end

  def delete(%Array{} = array, element) do
    to_list(array)
    |> List.delete(element)
    |> from_list()
  end

  def duplicate(elem, n) when Meal.is_non_neg_integer(n) do
    List.duplicate(elem, n)
    |> from_list()
  end

  def first(%Array{} = array) do
    first(array, default(array))
  end

  def first(%Array{} = array, default) do
    get(array, 0, default)
  end

  def last(%Array{} = array) do
    last(array, default(array))
  end

  def last(%Array{} = array, default) do
    get(array, -1, default)
  end

  def pop_at(%Array{} = array, index) when is_integer(index) do
    pop_at(array, index, default(array))
  end

  def pop_at(%Array{} = array, index, default) when is_integer(index) do
    to_list(array)
    |> List.pop_at(index, default)
    |> then(fn {element, list} -> {element, from_list(list)} end)
  end

  def pop_slice(%Array{} = array, first..last) do
    size = size(array)
    result = with first when first >= 0 and first < size <- Meal.normalize_index(array, first),
                  last when first <= last <- Meal.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)
      {
        Enum.slice(array, first..last),
        Enum.concat(
          [Enum.slice(array, 0, left_count), Enum.slice(array, last + 1, right_count)]
        )
      }
    end

    case result do
      v when not is_tuple(v) -> {new(), array}
      {popped, remained} -> {from_list(popped), from_list(remained)}
    end
  end

  def replace_at(%Array{} = array, index, value) when is_integer(index) do
    to_list(array)
    |> List.replace_at(index, value)
    |> from_list()
  end

  def replace_slice(%Array{} = array, first..last, enumerable) do
    size = size(array)
    result = with first when first >= 0 and first < size <- Meal.normalize_index(array, first),
                  last when first <= last <- Meal.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)
      Enum.concat(
        [Enum.slice(array, 0, left_count), Meal.enumerable_wrap(enumerable), Enum.slice(array, last + 1, right_count)]
      )
    end

    case result do
      v when not is_list(v) -> array
      list -> from_list(list)
    end
  end

  def replace(%Array{} = array, index, value) when is_integer(index) do
    replace_at(array, index, value)
  end

  def replace(%Array{} = array, first..last, enumerable) do
    replace_slice(array, first..last, enumerable)
  end

  def starts_with?(%Array{} = array, %Array{} = prefix) do
    List.starts_with?(to_list(array), to_list(prefix))
  end

  def update_at(%Array{} = array, index, fun) when is_integer(index) and is_function(fun, 1) do
    to_list(array)
    |> List.update_at(index, fun)
    |> from_list()
  end

  def update_slice(%Array{} = array, first..last, fun) when is_function(fun, 1) do
    size = size(array)
    result = with first when first >= 0 and first < size <- Meal.normalize_index(array, first),
                  last when first <= last <- Meal.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)
      Enum.concat(
        [
          Enum.slice(array, 0, left_count),
          fun.(Enum.slice(array, first..last)),
          Enum.slice(array, last + 1, right_count)
        ]
      )
    end

    case result do
      v when not is_list(v) -> array
      list -> from_list(list)
    end
  end

  def update(%Array{} = array, index, fun) when is_integer(index) and is_function(fun, 1) do
    update_at(array, index, fun)
  end

  def update(%Array{} = array, first..last, fun) when is_function(fun, 1) do
    update_slice(array, first..last, fun)
  end

  def zip(%Array{} = array) do
    Enum.map(array, &to_list(&1))
    |> List.zip()
    |> from_list()
  end

  def foldl(%Array{} = array, acc, fun) when is_function(fun, 3) do
    :array.foldl(&fun.(&2, &1, &3), acc, array.__array__)
  end

  def foldr(%Array{} = array, acc, fun) when is_function(fun, 3) do
    :array.foldr(&fun.(&2, &1, &3), acc, array.__array__)
  end

  def map(%Array{} = array, fun) when is_function(fun, 2) do
    :array.map(&fun.(&2, &1), array.__array__)
    |> from_erlang_array()
  end

  def sparse_foldl(%Array{} = array, acc, fun) when is_function(fun, 3) do
    :array.sparse_foldl(&fun.(&2, &1, &3), acc, array.__array__)
  end

  def sparse_foldr(%Array{} = array, acc, fun) when is_function(fun, 3) do
    :array.sparse_foldr(&fun.(&2, &1, &3), acc, array.__array__)
  end

  def sparse_map(%Array{} = array, fun) when is_function(fun, 2) do
    :array.sparse_map(&fun.(&2, &1), array.__array__)
    |> from_erlang_array()
  end

  def reset(%Array{} = array, index) when is_integer(index) do
    index = Meal.normalize_index(array, index)
    :array.reset(index, array.__array__)
    |> from_erlang_array()
  end

  def resize(%Array{} = array) do
    :array.resize(array.__array__)
    |> from_erlang_array()
  end

  def resize(%Array{} = array, size) when Meal.is_non_neg_integer(size) do
    :array.resize(size, array.__array__)
    |> from_erlang_array()
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Array{} = array, opts) do
      concat(["##{@for}", to_doc(Array.to_list(array), opts)])
    end
  end

  defimpl Enumerable do
    def count(%Array{} = array) do
      {:ok, Array.size(array)}
    end

    def member?(%Array{}, _element) do
      {:error, __MODULE__}
    end

    def slice(%Array{} = array) do
      {
        :ok,
        Array.size(array),
        fn start, len ->
          Enum.reduce(start..(start + len - 1), [], fn idx, acc -> [Array.get(array, idx) | acc] end)
          |> Enum.reverse()
        end
      }
    end

    def reduce(_array, {:halt, acc}, _fun), do: {:halted, acc}
    def reduce(array, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(array, &1, fun)}
    def reduce(%Array{} = array, {:cont, acc}, fun) do
      if Array.size(array) == 0 do
        {:done, acc}
      else
        [head | tail] = Array.to_list(array)
        reduce(Array.from_list(tail), fun.(head, acc), fun)
      end
    end
  end

  defimpl Collectable do
    def into(%Array{} = array) do
      collector_fun = fn
        (acc, {:cont, elem}) -> Array.insert_at(acc, -1, elem)
        (acc, :done) -> acc
        (_, :halt) -> :ok
      end
      {array, collector_fun}
    end
  end

  @impl Access
  def fetch(%Array{} = array, index) when is_integer(index) do
    index = Meal.normalize_index(array, index)
    if index >= 0 && index < size(array) do
      {:ok, get(array, index)}
    else
      :error
    end
  end

  @impl Access
  def fetch(%Array{} = array, first..last) do
    array = slice(array, first..last)
    if size(array) == 0 do
      :error
    else
      {:ok, array}
    end
  end

  @impl Access
  def fetch(nil, index) when is_integer(index) do
    :error
  end

  @impl Access
  def pop(%Array{} = array, index) when is_integer(index) do
    pop_at(array, index)
  end

  @impl Access
  def pop(%Array{} = array, first..last) do
    pop_slice(array, first..last)
  end

  @impl Access
  def get_and_update(%Array{} = array, index, fun) when is_integer(index) and is_function(fun, 1) do
    result = array[index]
             |> then(fun)
    case result do
      :pop -> pop(array, index)
      {cur_value, new_value} -> {cur_value, replace_at(array, index, new_value)}
    end
  end

  @impl Access
  def get_and_update(%Array{} = array, first..last, fun) when is_function(fun, 1) do
    result = array[first..last]
             |> then(fun)
    case result do
      :pop -> pop(array, first..last)
      {cur_value, new_value} -> {cur_value, replace_slice(array, first..last, Meal.enumerable_wrap(new_value))}
    end
  end
end