defmodule Meal.Parallel do
  def map(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Task.await_many(:infinity)
  end

  def map_every(enumerable, nth, fun) do
    enumerable
    |> Enum.map_every(
      nth,
      &Task.async(fn -> fun.(&1) end)
    )
    |> Enum.map_every(nth, &Task.await(&1, :infinity))
  end

  def map_intersperse(enumerable, separator, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Enum.map_intersperse(
      separator,
      &Task.await(&1, :infinity)
    )
  end

  def map_join(enumerable, joiner \\ "", fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Enum.map_join(joiner, &Task.await(&1, :infinity))
  end

  def flat_map(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Enum.flat_map(&Task.await(&1, :infinity))
  end

  def chunk_by(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> {fun.(&1), &1} end))
    |> Enum.reduce(
      {[], [], []},
      fn
        task, {[], [], []} ->
          {result, element} = Task.await(task, :infinity)
          {[result], [element], []}

        task, {[last_result], chunk, chunks} ->
          {result, element} = Task.await(task, :infinity)

          if last_result === result do
            {[last_result], [element | chunk], chunks}
          else
            {[result], [element], [Enum.reverse(chunk) | chunks]}
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
    enumerable
    |> Enum.map(&Task.async(fn -> {fun.(&1), &1} end))
    |> Enum.reduce(
      [],
      fn task, acc ->
        {result, element} = Task.await(task, :infinity)
        if result, do: [element | acc], else: acc
      end
    )
    |> Enum.reverse()
  end

  def reject(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> {fun.(&1), &1} end))
    |> Enum.reduce(
      [],
      fn task, acc ->
        {result, element} = Task.await(task, :infinity)
        if !result, do: [element | acc], else: acc
      end
    )
    |> Enum.reverse()
  end

  def find(enumerable, default \\ nil, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> {fun.(&1), &1} end))
    |> Enum.reduce(
      [],
      fn
        task, [result] ->
          Task.shutdown(task, :brutal_kill)
          [result]

        task, [] ->
          {result, element} = Task.await(task, :infinity)

          if result do
            [element]
          else
            []
          end
      end
    )
    |> Enum.at(0, default)
  end

  def find_index(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Stream.with_index()
    |> Enum.reduce(
      [],
      fn
        {task, _}, [index] ->
          Task.shutdown(task, :brutal_kill)
          [index]

        {task, index}, [] ->
          result = Task.await(task, :infinity)

          if result do
            [index]
          else
            []
          end
      end
    )
    |> Enum.at(0)
  end

  def find_value(enumerable, default \\ nil, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Enum.reduce(
      [],
      fn
        task, [result] ->
          Task.shutdown(task, :brutal_kill)
          [result]

        task, [] ->
          result = Task.await(task, :infinity)

          if result do
            [result]
          else
            []
          end
      end
    )
    |> Enum.at(0, default)
  end

  def frequencies_by(enumerable, fun) do
    enumerable
    |> Enum.map(&Task.async(fn -> fun.(&1) end))
    |> Enum.reduce(
      %{},
      fn task, acc ->
        result = Task.await(task, :infinity)
        Map.update(acc, result, 1, &(&1 + 1))
      end
    )
  end

  def group_by(enumerable, key_fun, value_fun \\ fn x -> x end) do
    enumerable
    |> Enum.map(&Task.async(fn -> {key_fun.(&1), value_fun.(&1)} end))
    |> Enum.reduce(
      %{},
      fn task, acc ->
        {key, value} = Task.await(task, :infinity)
        Map.update(acc, key, [value], &List.insert_at(&1, -1, value))
      end
    )
  end

  def max_by(enumerable, fun, sorter \\ &>=/2, empty_fallback \\ fn -> raise Enum.EmptyError end) do
    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      enumerable
      |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
      |> Enum.max_by(
        fn {task, _} ->
          Task.await(task, :infinity)
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
      enumerable
      |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
      |> Enum.min_by(
        fn {task, _} ->
          Task.await(task, :infinity)
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
      {{_, min}, {_, max}} =
        enumerable
        |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
        |> Enum.min_max_by(
          fn {task, _} ->
            Task.await(task, :infinity)
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
      enumerable
      |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
      |> Enum.sort_by(
        fn {task, _} ->
          Task.await(task, :infinity)
        end,
        sorter
      )
      |> Enum.map(&elem(&1, 1))
    end
  end

  def split_while(enumerable, fun) do
    enumerable
    |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
    |> Enum.reduce([[], []], fn
      {task, e}, [left_split, []] ->
        result = Task.await(task, :infinity)
        if result, do: [[e | left_split], []], else: [left_split, [result]]

      {task, e}, [left_split, right_split] ->
        Task.shutdown(task, :brutal_kill)
        [left_split, [e | right_split]]
    end)
    |> then(fn [left_split, right_split] ->
      [Enum.reverse(left_split), Enum.reverse(right_split)]
    end)
  end

  def split_with(enumerable, fun) do
    enumerable
    |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
    |> Enum.reduce([[], []], fn {task, e}, [truthy_split, falsy_split] ->
      result = Task.await(task, :infinity)

      if result do
        [[e | truthy_split], falsy_split]
      else
        [truthy_split, [e | falsy_split]]
      end
    end)
    |> then(fn [truthy_split, falsy_split] ->
      [Enum.reverse(truthy_split), Enum.reverse(falsy_split)]
    end)
  end

  def uniq_by(enumerable, fun) do
    if Enum.empty?(enumerable) do
      []
    else
      enumerable
      |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
      |> Enum.uniq_by(fn {task, _} ->
        Task.await(task, :infinity)
      end)
      |> Enum.map(&elem(&1, 1))
    end
  end

  def zip_with(enumerables, fun) do
    enumerables
    |> Enum.zip_with(&Task.async(fn -> fun.(&1) end))
    |> Enum.map(&Task.await(&1, :infinity))
  end

  def zip_with(enumerable1, enumerable2, fun) do
    Enum.zip_with(
      enumerable1,
      enumerable2,
      &Task.async(fn -> fun.(&1, &2) end)
    )
    |> Enum.map(&Task.await(&1, :infinity))
  end
end
