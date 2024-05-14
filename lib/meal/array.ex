defmodule Meal.Array do
  @behaviour Access

  require Meal
  alias __MODULE__

  defstruct size: 0, default: nil, __array__: :array.new(default: nil)

  def new() do
    %Array{}
  end

  def new(size) when Meal.is_non_neg_integer(size) do
    new(size: size, default: nil)
  end

  def new(size: size, default: default_value) when Meal.is_non_neg_integer(size) do
    %Array{
      size: size,
      default: default_value,
      __array__: :array.new(size: size, default: default_value, fixed: false)
    }
  end

  def from_erlang_array(array) do
    if :array.is_array(array) do
      %Array{size: :array.size(array), default: :array.default(array), __array__: array}
    else
      raise "can not create #{__MODULE__} from #{array}"
    end
  end

  def from_list(list) when is_list(list) do
    from_list(list, nil)
  end

  def from_list(list, default) when is_list(list) do
    :array.from_list(list, default)
    |> from_erlang_array()
  end

  def from_index_paris(index_pairs) when is_list(index_pairs) do
    from_index_paris(index_pairs, nil)
  end

  def from_index_paris(index_pairs, default) when is_list(index_pairs) do
    :array.from_orddict(Enum.map(index_pairs, &{elem(&1, 1), elem(&1, 0)}), default)
    |> from_erlang_array()
  end

  def from_enumerable(enumerable) do
    from_enumerable(enumerable, nil)
  end

  def from_enumerable(enumerable, default) do
    if !Meal.Enum.enumerable?(enumerable) do
      raise "can not create #{__MODULE__} from #{enumerable}"
    end

    enumerable
    |> Enum.to_list()
    |> :array.from_list(default)
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

  def get(%Array{} = array, index, default) when is_integer(index) do
    index = Meal.Enum.normalize_index(array, index)

    if index < 0 || index >= size(array) do
      default
    else
      :array.get(index, array.__array__)
    end
  end

  def get(%Array{} = array, index) when is_integer(index) do
    get(array, index, default(array))
  end

  def slice(%Array{} = array, first..last) do
    Enum.slice(array, first..last)
    |> from_list()
  end

  def slice(%Array{} = array, start_index, length)
      when is_integer(start_index) and is_integer(length) do
    cond do
      length < 0 -> Enum.slice(array, start_index..-1)
      length >= 0 -> Enum.slice(array, start_index, length)
    end
    |> from_list()
  end

  def set(%Array{} = array, index, value) when is_integer(index) do
    index = Meal.Enum.normalize_index(array, index)

    :array.set(index, value, array.__array__)
    |> from_erlang_array()
  end

  def insert_at(%Array{} = array, index, value) when is_integer(index) do
    insert_splicing_at(array, index, [value])
  end

  def insert_splicing_at(%Array{} = array, index, enumerable) when is_integer(index) do
    index =
      if index < 0 do
        Meal.Enum.normalize_index(array, index) + 1
      else
        Meal.Enum.normalize_index(array, index)
      end
      |> min(size(array))
      |> max(0)

    left_count = Range.size(0..(index - 1)//1)
    right_count = Range.size((index + 1)..size(array)//1)

    Enum.concat([
      Enum.slice(array, 0, left_count),
      Meal.Enum.enumerable_wrap(enumerable),
      Enum.slice(array, left_count, right_count)
    ])
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

  def delete_slice(%Array{} = array, start, length)
      when is_integer(start) and is_integer(length) do
    cond do
      length < 0 -> replace_slice(array, start..-1, [])
      length >= 0 -> replace_slice(array, start, length, [])
    end
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

    with first when first >= 0 and first < size <- Meal.Enum.normalize_index(array, first),
         last when first <= last <- Meal.Enum.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)

      {
        Enum.slice(array, first..last)
        |> from_list(),
        Enum.concat([Enum.slice(array, 0, left_count), Enum.slice(array, last + 1, right_count)])
        |> from_list()
      }
    else
      _ -> {new(), array}
    end
  end

  def pop_slice(%Array{} = array, start, length) when is_integer(start) and is_integer(length) do
    cond do
      length == 0 ->
        {new(), array}

      length < 0 ->
        pop_slice(array, start..-1)

      length > 0 && start >= 0 ->
        pop_slice(array, start..(start + length - 1))

      length > 0 && start < 0 && start + length - 1 < 0 ->
        pop_slice(array, start..(start + length - 1))

      length > 0 && start < 0 && start + length - 1 >= 0 ->
        pop_slice(array, start..-1)
    end
  end

  def replace_at(%Array{} = array, index, value) when is_integer(index) do
    to_list(array)
    |> List.replace_at(index, value)
    |> from_list()
  end

  def replace_slice(%Array{} = array, first..last, enumerable) do
    size = size(array)

    with first when first >= 0 and first < size <- Meal.Enum.normalize_index(array, first),
         last when first <= last <- Meal.Enum.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)

      Enum.concat([
        Enum.slice(array, 0, left_count),
        Meal.Enum.enumerable_wrap(enumerable),
        Enum.slice(array, last + 1, right_count)
      ])
      |> from_list()
    else
      _ -> array
    end
  end

  def replace_slice(%Array{} = array, start, length, enumerable)
      when is_integer(start) and is_integer(length) do
    cond do
      length == 0 ->
        array

      length < 0 ->
        replace_slice(array, start..-1, enumerable)

      length > 0 && start >= 0 ->
        replace_slice(array, start..(start + length - 1), enumerable)

      length > 0 && start < 0 && start + length - 1 < 0 ->
        replace_slice(array, start..(start + length - 1), enumerable)

      length > 0 && start < 0 && start + length - 1 >= 0 ->
        replace_slice(array, start..-1, enumerable)
    end
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

    with first when first >= 0 and first < size <- Meal.Enum.normalize_index(array, first),
         last when first <= last <- Meal.Enum.normalize_index(array, last) do
      left_count = Range.size(0..(first - 1)//1)
      right_count = Range.size((last + 1)..(size(array) - 1)//1)

      Enum.concat([
        Enum.slice(array, 0, left_count),
        fun.(Enum.slice(array, first..last)),
        Enum.slice(array, last + 1, right_count)
      ])
      |> from_list()
    else
      _ -> array
    end
  end

  def update_slice(%Array{} = array, start, length, fun)
      when is_integer(start) and is_integer(length) and is_function(fun, 1) do
    cond do
      length == 0 ->
        array

      length < 0 ->
        update_slice(array, start..-1, fun)

      length > 0 && start >= 0 ->
        update_slice(array, start..(start + length - 1), fun)

      length > 0 && start < 0 && start + length - 1 < 0 ->
        update_slice(array, start..(start + length - 1), fun)

      length > 0 && start < 0 && start + length - 1 >= 0 ->
        update_slice(array, start..-1, fun)
    end
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
    index = Meal.Enum.normalize_index(array, index)

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

  def bsearch(%Array{} = array, target) do
    case size(array) do
      0 ->
        {:insert_index, 0}

      1 ->
        cond do
          array[0] === target -> {:target_index, 0}
          array[0] < target -> {:insert_index, 1}
          array[0] > target -> {:insert_index, 0}
        end

      _ ->
        if array[0] <= array[1] do
          _bsearch(array, target, 0, size(array) - 1, :asc)
        else
          _bsearch(array, target, 0, size(array) - 1, :desc)
        end
    end
  end

  defp _bsearch(_, _, low, high, _) when low > high, do: {:insert_index, low}

  defp _bsearch(%Array{} = array, target, low, high, :asc) do
    mid_idx = div(low + high, 2)
    pilot = array[mid_idx]

    cond do
      pilot === target -> {:target_index, mid_idx}
      pilot < target -> _bsearch(array, target, mid_idx + 1, high, :asc)
      pilot > target -> _bsearch(array, target, low, mid_idx - 1, :asc)
    end
  end

  defp _bsearch(%Array{} = array, target, low, high, :desc) do
    mid_idx = div(low + high, 2)
    pilot = array[mid_idx]

    cond do
      pilot === target -> {:target_index, mid_idx}
      pilot < target -> _bsearch(array, target, low, mid_idx - 1, :desc)
      pilot > target -> _bsearch(array, target, mid_idx + 1, high, :desc)
    end
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

    def member?(%Array{} = array, _element) do
      if Array.size(array) == 0 do
        {:ok, false}
      else
        {:error, __MODULE__}
      end
    end

    def slice(%Array{} = array) do
      size = Array.size(array)

      slice_fun =
        case size do
          0 ->
            fn _, _ -> [] end

          _ ->
            fn start, len ->
              Enum.reduce(start..(start + len - 1), [], fn idx, acc ->
                [Array.get(array, idx) | acc]
              end)
              |> Enum.reverse()
            end
        end

      {:ok, size, slice_fun}
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
        acc, {:cont, elem} -> Array.insert_at(acc, -1, elem)
        acc, :done -> acc
        _, :halt -> :ok
      end

      {array, collector_fun}
    end
  end

  @impl Access
  def fetch(%Array{} = array, index) when is_integer(index) do
    index = Meal.Enum.normalize_index(array, index)

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
  def fetch(%Array{} = array, {start, length}) when is_integer(start) and is_integer(length) do
    array = slice(array, start, length)

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
  def pop(%Array{} = array, {start, length}) when is_integer(start) and is_integer(length) do
    pop_slice(array, start, length)
  end

  @impl Access
  def get_and_update(%Array{} = array, index, fun)
      when is_integer(index) and is_function(fun, 1) do
    result =
      array[index]
      |> then(fun)

    case result do
      :pop -> pop(array, index)
      {cur_value, new_value} -> {cur_value, replace_at(array, index, new_value)}
    end
  end

  @impl Access
  def get_and_update(%Array{} = array, first..last, fun) when is_function(fun, 1) do
    result =
      array[first..last]
      |> then(fun)

    case result do
      :pop ->
        pop(array, first..last)

      {cur_value, new_value} ->
        {cur_value, replace_slice(array, first..last, Meal.Enum.enumerable_wrap(new_value))}
    end
  end

  @impl Access
  def get_and_update(%Array{} = array, {start, length}, fun)
      when is_integer(start) and is_integer(length) and is_function(fun, 1) do
    result =
      array[{start, length}]
      |> then(fun)

    case result do
      :pop ->
        pop(array, {start, length})

      {cur_value, new_value} ->
        {cur_value, replace_slice(array, start, length, Meal.Enum.enumerable_wrap(new_value))}
    end
  end
end
