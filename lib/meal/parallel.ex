defmodule Meal.Parallel do
  def map(enumerable, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.map(fn {:ok, v} -> v end)
  end

  def map_every(enumerable, nth, fun) do
    mapped_iter =
      enumerable
      |> Stream.take_every(nth)
      |> Task.async_stream(fun, timeout: :infinity)
      |> Stream.map(fn {:ok, v} -> v end)
      |> Meal.Iterator.new()

    result =
      enumerable
      |> Enum.map_every(nth, fn _ ->
        {:ok, v} = Meal.Iterator.next(mapped_iter)
        v
      end)

    Meal.Iterator.stop(mapped_iter)

    result
  end

  def map_intersperse(enumerable, separator, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.map(fn {:ok, v} -> v end)
    |> Enum.map_intersperse(separator, & &1)
  end

  def map_join(enumerable, joiner \\ "", fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.map(fn {:ok, v} -> v end)
    |> Enum.map_join(joiner, & &1)
  end

  def flat_map(enumerable, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.map(fn {:ok, v} -> v end)
    |> Stream.flat_map(& &1)
  end

  def chunk_by(enumerable, fun) do
    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
    |> Stream.chunk_by(fn {:ok, {value, _}} -> value end)
    |> Stream.map(fn chunk -> Enum.map(chunk, fn {:ok, {_, element}} -> element end) end)
  end

  def each(enumerable, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Stream.run()

    :ok
  end

  def filter(enumerable, fun) do
    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
    |> Stream.filter(fn {:ok, {result, _}} -> result end)
    |> Stream.map(fn {:ok, {_, element}} -> element end)
  end

  def reject(enumerable, fun) do
    filter(enumerable, &(!fun.(&1)))
  end

  def find(enumerable, default \\ nil, fun) do
    enumerable
    |> Stream.chunk_every(System.schedulers_online())
    |> Enum.reduce_while(default, fn chunk, acc ->
      case _find(chunk, fun) do
        {:ok, element} -> {:halt, element}
        :error -> {:cont, acc}
      end
    end)
  end

  def find_value(enumerable, default \\ nil, fun) do
    enumerable
    |> Stream.chunk_every(System.schedulers_online())
    |> Enum.reduce_while(default, fn chunk, acc ->
      case _find_value(chunk, fun) do
        {:ok, result} -> {:halt, result}
        :error -> {:cont, acc}
      end
    end)
  end

  def find_index(enumerable, fun) do
    enumerable
    |> Stream.with_index()
    |> find(nil, fn {element, _} -> fun.(element) end)
    |> then(fn
      nil -> nil
      {_, index} -> index
    end)
  end

  defp _find(enumerable, fun) do
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
    |> Enum.fetch(0)
  end

  defp _find_value(enumerable, fun) do
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
    |> Enum.fetch(0)
  end

  def frequencies_by(enumerable, fun) do
    enumerable
    |> Task.async_stream(fun, timeout: :infinity)
    |> Enum.reduce(
      %{},
      fn {:ok, result}, acc ->
        Map.update(acc, result, 1, &(&1 + 1))
      end
    )
  end

  def group_by(enumerable, key_fun, value_fun \\ fn x -> x end) do
    enumerable
    |> Task.async_stream(&{key_fun.(&1), value_fun.(&1)}, timeout: :infinity)
    |> Enum.reduce(
      %{},
      fn {:ok, key, value}, acc ->
        Map.update(acc, key, [value], &List.insert_at(&1, -1, value))
      end
    )
  end

  def max_by(enumerable, fun, sorter \\ &>=/2, empty_fallback \\ fn -> raise Enum.EmptyError end) do
    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
      |> Enum.max_by(
        fn {:ok, {by, _}} ->
          by
        end,
        sorter,
        empty_fallback
      )
      |> elem(1)
      |> elem(1)
    end
  end

  def min_by(enumerable, fun, sorter \\ &<=/2, empty_fallback \\ fn -> raise Enum.EmptyError end) do
    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
      |> Enum.min_by(
        fn {:ok, {by, _}} ->
          by
        end,
        sorter,
        empty_fallback
      )
      |> elem(1)
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
      {{:ok, {_, min}}, {:ok, {_, max}}} =
        enumerable
        |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
        |> Enum.min_max_by(
          fn {:ok, {by, _}} ->
            by
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
      |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
      |> Enum.sort_by(
        fn {:ok, {by, _}} ->
          by
        end,
        sorter
      )
      |> Enum.map(fn {:ok, {_, element}} -> element end)
    end
  end

  def split_while(enumerable, fun) do
    enumerable
    |> Stream.chunk_every(System.schedulers_online())
    |> Enum.reduce([[], []], fn
      chunk, [left_acc, []] ->
        case _split_while(chunk, fun) do
          [left_split, []] -> [left_acc ++ left_split, []]
          [left_split, right_split] -> [left_acc ++ left_split, right_split]
        end

      chunk, [left_acc, right_acc] ->
        [left_acc, right_acc ++ chunk]
    end)
  end

  defp _split_while(enumerable, fun) do
    enumerable
    |> Enum.map(&{Task.async(fn -> fun.(&1) end), &1})
    |> Enum.reduce([[], []], fn
      {task, e}, [left_split, []] ->
        result = Task.await(task, :infinity)
        if result, do: [[e | left_split], []], else: [left_split, [e]]

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
    |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
    |> Enum.reduce([[], []], fn {:ok, {result, e}}, [truthy_split, falsy_split] ->
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
      |> Task.async_stream(&{fun.(&1), &1}, timeout: :infinity)
      |> Stream.uniq_by(fn {:ok, {by, _}} ->
        by
      end)
      |> Stream.map(fn {:ok, {_, element}} -> element end)
    end
  end

  def zip_with(enumerables, fun) do
    enumerables
    |> Stream.zip()
    |> Task.async_stream(fun, timeout: :infinity)
  end

  def zip_with(enumerable1, enumerable2, fun) do
    Stream.zip(enumerable1, enumerable2)
    |> Task.async_stream(fun, timeout: :infinity)
  end
end
