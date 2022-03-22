defmodule Meal.Parallel do
  def map(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_map, fun.(&1)}) end))
    |> Enum.map(&receive do: ({^&1, :parallel_map, result} -> result))
  end

  def map_every(enumerable, nth, fun) do
    self = self()

    enumerable
    |> Enum.map_every(
      nth,
      &spawn_link(fn -> send(self, {self(), :parallel_map_every, fun.(&1)}) end)
    )
    |> Enum.map_every(nth, &receive(do: ({^&1, :parallel_map_every, result} -> result)))
  end

  def map_intersperse(enumerable, separator, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_map_intersperse, fun.(&1)}) end))
    |> Enum.map_intersperse(
      separator,
      &receive(do: ({^&1, :parallel_map_intersperse, result} -> result))
    )
  end

  def map_join(enumerable, joiner \\ "", fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_map_join, fun.(&1)}) end))
    |> Enum.map_join(joiner, &receive(do: ({^&1, :parallel_map_join, result} -> result)))
  end

  def flat_map(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_flat_map, fun.(&1)}) end))
    |> Enum.flat_map(&receive do: ({^&1, :parallel_flat_map, result} -> result))
  end

  def chunk_by(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_chunk_by, fun.(&1), &1}) end))
    |> Enum.reduce(
      {[], [], []},
      fn
        pid, {[], [], []} ->
          receive do
            {^pid, :parallel_chunk_by, result, element} -> {[result], [element], []}
          end

        pid, {[last_result], chunk, chunks} ->
          receive do
            {^pid, :parallel_chunk_by, result, element} ->
              if last_result === result do
                {[last_result], [element | chunk], chunks}
              else
                {[result], [element], [Enum.reverse(chunk) | chunks]}
              end
          end
      end
    )
    |> then(fn
      {_, [], chunks} -> chunks
      {_, chunk, chunks} -> [Enum.reverse(chunk) | chunks]
    end)
    |> Enum.reverse()
  end

  def each(enumerable, fun) do
    map(enumerable, fun)
    :ok
  end

  def filter(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_filter, fun.(&1), &1}) end))
    |> Enum.reduce(
      [],
      fn pid, acc ->
        receive do
          {^pid, :parallel_filter, result, element} -> if result, do: [element | acc], else: acc
        end
      end
    )
    |> Enum.reverse()
  end

  def reject(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_reject, fun.(&1), &1}) end))
    |> Enum.reduce(
      [],
      fn pid, acc ->
        receive do
          {^pid, :parallel_reject, result, element} -> if !result, do: [element | acc], else: acc
        end
      end
    )
    |> Enum.reverse()
  end

  def find(enumerable, default \\ nil, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_find, fun.(&1), &1}) end))
    |> Enum.reduce_while(
      [],
      fn pid, acc ->
        receive do
          {^pid, :parallel_find, result, element} ->
            if result do
              {:halt, [element]}
            else
              {:cont, acc}
            end
        end
      end
    )
    |> Enum.at(0, default)
  end

  def find_index(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_find_index, fun.(&1)}) end))
    |> Stream.with_index()
    |> Enum.reduce_while(
      [],
      fn {pid, index}, acc ->
        receive do
          {^pid, :parallel_find_index, result} ->
            if result do
              {:halt, [index]}
            else
              {:cont, acc}
            end
        end
      end
    )
    |> Enum.at(0)
  end

  def find_value(enumerable, default \\ nil, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_find_value, fun.(&1)}) end))
    |> Enum.reduce_while(
      [],
      fn pid, acc ->
        receive do
          {^pid, :parallel_find_value, result} ->
            if result do
              {:halt, [result]}
            else
              {:cont, acc}
            end
        end
      end
    )
    |> Enum.at(0, default)
  end

  def frequencies_by(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&spawn_link(fn -> send(self, {self(), :parallel_frequencies_by, fun.(&1)}) end))
    |> Enum.reduce(
      %{},
      fn pid, acc ->
        receive do
          {^pid, :parallel_frequencies_by, result} ->
            Map.update(acc, result, 1, &(&1 + 1))
        end
      end
    )
  end

  def group_by(enumerable, key_fun, value_fun \\ fn x -> x end) do
    self = self()

    enumerable
    |> Enum.map(
      &spawn_link(fn ->
        send(self, {self(), :parallel_group_by, [key_fun.(&1), value_fun.(&1)]})
      end)
    )
    |> Enum.reduce(
      %{},
      fn pid, acc ->
        receive do
          {^pid, :parallel_group_by, [key, value]} ->
            Map.update(acc, key, [value], &List.insert_at(&1, -1, value))
        end
      end
    )
  end

  def max_by(enumerable, fun, sorter \\ &>=/2, empty_fallback \\ fn -> raise Enum.EmptyError end) do
    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      self = self()

      enumerable
      |> Enum.map(&{spawn_link(fn -> send(self, {self(), :parallel_max_by, fun.(&1)}) end), &1})
      |> Enum.max_by(
        fn {pid, _} ->
          receive do
            {^pid, :parallel_max_by, result} -> result
          end
        end,
        sorter,
        empty_fallback
      )
      |> elem(1)
    end
  end

  def min_by(enumerable, fun, sorter \\ &<=/2, empty_fallback \\ fn -> raise Enum.EmptyError end) do
    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      self = self()

      enumerable
      |> Enum.map(&{spawn_link(fn -> send(self, {self(), :parallel_min_by, fun.(&1)}) end), &1})
      |> Enum.min_by(
        fn {pid, _} ->
          receive do
            {^pid, :parallel_min_by, result} -> result
          end
        end,
        sorter,
        empty_fallback
      )
      |> elem(1)
    end
  end

  def min_max_by(
        enumerable,
        fun,
        sorter_or_empty_fallback \\ &</2,
        empty_fallback \\ fn -> raise Enum.EmptyError end
      ) do
    if Enum.empty?(enumerable) do
      if is_function(sorter_or_empty_fallback, 0) do
        sorter_or_empty_fallback.()
      else
        empty_fallback.()
      end
    else
      self = self()

      {{_, min}, {_, max}} =
        enumerable
        |> Enum.map(
          &{spawn_link(fn -> send(self, {self(), :parallel_min_max_by, fun.(&1)}) end), &1}
        )
        |> Enum.min_max_by(
          fn {pid, _} ->
            receive do
              {^pid, :parallel_min_max_by, result} -> result
            end
          end,
          sorter_or_empty_fallback,
          empty_fallback
        )

      {min, max}
    end
  end

  def sort_by(enumerable, fun, sorter \\ &<=/2) do
    if Enum.empty?(enumerable) do
      []
    else
      self = self()

      enumerable
      |> Enum.map(&{spawn_link(fn -> send(self, {self(), :parallel_sort_by, fun.(&1)}) end), &1})
      |> Enum.sort_by(
        fn {pid, _} ->
          receive do
            {^pid, :parallel_sort_by, result} -> result
          end
        end,
        sorter
      )
      |> Enum.map(&elem(&1, 1))
    end
  end

  def split_while(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(
      &{spawn_link(fn -> send(self, {self(), :parallel_split_while, fun.(&1)}) end), &1}
    )
    |> Enum.split_while(fn {pid, _} ->
      receive do
        {^pid, :parallel_split_while, result} -> result
      end
    end)
    |> then(fn {list1, list2} ->
      {
        get_in(list1, [Access.all(), Access.elem(1)]),
        get_in(list2, [Access.all(), Access.elem(1)])
      }
    end)
  end

  def split_with(enumerable, fun) do
    self = self()

    enumerable
    |> Enum.map(&{spawn_link(fn -> send(self, {self(), :parallel_split_with, fun.(&1)}) end), &1})
    |> Enum.split_with(fn {pid, _} ->
      receive do
        {^pid, :parallel_split_with, result} -> result
      end
    end)
    |> then(fn {list1, list2} ->
      {
        get_in(list1, [Access.all(), Access.elem(1)]),
        get_in(list2, [Access.all(), Access.elem(1)])
      }
    end)
  end

  def uniq_by(enumerable, fun) do
    if Enum.empty?(enumerable) do
      []
    else
      self = self()

      enumerable
      |> Enum.map(&{spawn_link(fn -> send(self, {self(), :parallel_uniq_by, fun.(&1)}) end), &1})
      |> Enum.uniq_by(fn {pid, _} ->
        receive do
          {^pid, :parallel_uniq_by, result} -> result
        end
      end)
      |> Enum.map(&elem(&1, 1))
    end
  end

  def zip_with(enumerables, fun) do
    self = self()

    enumerables
    |> Enum.zip_with(&spawn_link(fn -> send(self, {self(), :parallel_zip_with, fun.(&1)}) end))
    |> Enum.map(&receive do: ({^&1, :parallel_zip_with, result} -> result))
  end

  def zip_with(enumerable1, enumerable2, fun) do
    self = self()

    Enum.zip_with(
      enumerable1,
      enumerable2,
      &spawn_link(fn -> send(self, {self(), :parallel_zip_with_3, fun.(&1, &2)}) end)
    )
    |> Enum.map(&receive do: ({^&1, :parallel_zip_with_3, result} -> result))
  end
end
