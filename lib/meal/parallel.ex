defmodule Meal.Parallel do
  def map(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Stream.map(fn
      {:ok, v} -> v
      timeout_result -> timeout_result
    end)
  end

  def map_every(enumerable, nth, fun, opts \\ [])
  def map_every(enumerable, 0, fun, _), do: Stream.map_every(enumerable, 0, fun)

  def map_every(enumerable, nth, fun, opts) when is_integer(nth) and nth > 0 do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Stream.with_index()
    |> Task.async_stream(
      fn {element, index} ->
        if rem(index, nth) == 0 do
          fun.(element)
        else
          element
        end
      end,
      opts
    )
    |> Stream.map(fn
      {:ok, v} -> v
      timeout_result -> timeout_result
    end)
  end

  def map_intersperse(enumerable, separator, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Stream.map(fn
      {:ok, v} -> v
      timeout_result -> timeout_result
    end)
    |> Enum.map_intersperse(separator, & &1)
  end

  def map_join(enumerable, joiner \\ "", fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Stream.map(fn
      {:ok, v} -> v
      timeout_result -> timeout_result
    end)
    |> Enum.map_join(joiner, & &1)
  end

  def flat_map(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Stream.map(fn
      {:ok, v} -> v
      timeout_result -> [timeout_result]
    end)
    |> Stream.flat_map(& &1)
  end

  def chunk_by(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, opts)
    |> Stream.chunk_by(fn
      {:ok, {value, _}} -> value
      timeout_result -> timeout_result
    end)
    |> Stream.map(fn chunk ->
      Enum.map(chunk, fn
        {:ok, {_, element}} -> element
        timeout_result -> timeout_result
      end)
    end)
  end

  def each(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Stream.run()

    :ok
  end

  def filter(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, opts)
    |> Stream.filter(fn
      {:ok, {result, _}} -> result
      timeout_result -> timeout_result
    end)
    |> Stream.map(fn
      {:ok, {_, element}} -> element
      timeout_result -> timeout_result
    end)
  end

  def reject(enumerable, fun, opts \\ []) do
    filter(enumerable, &(!fun.(&1)), opts)
  end

  def find(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    Task.async(fn ->
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
      |> Enum.find(:not_found, fn
        {:ok, {value, _}} -> value
        _ -> false
      end)
      |> then(fn
        :not_found -> default
        {:ok, {_, element}} -> element
      end)
    end)
    |> Task.await(:infinity)
  end

  def find_value(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    Task.async(fn ->
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
      |> Enum.find_value(:not_found, fn
        {:ok, {value, _}} -> value
        _ -> false
      end)
      |> then(fn
        :not_found -> default
        value -> value
      end)
    end)
    |> Task.await(:infinity)
  end

  def find_index(enumerable, fun, opts \\ []) when is_function(fun, 1) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)
      
    Task.async(fn ->
      enumerable
      |> Stream.with_index()
      |> Task.async_stream(fn {element, index} -> {fun.(element), index} end, opts)
      |> Enum.find(:not_found, fn
        {:ok, {value, _}} -> value
        _ -> false
      end)
      |> then(fn
        :not_found -> nil
        {:ok, {_, index}} -> index
      end)
    end)
    |> Task.await(:infinity)
  end

  def frequencies_by(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)
      |> Keyword.put_new(:ordered, false)

    enumerable
    |> Task.async_stream(fun, opts)
    |> Enum.reduce(
      %{},
      fn
        {:ok, result}, acc ->
          Map.update(acc, result, 1, &(&1 + 1))

        timeout_result, acc ->
          Map.update(acc, timeout_result, 1, &(&1 + 1))
      end
    )
  end

  def group_by(enumerable, key_fun, opts \\ [], value_fun \\ fn x -> x end) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)
      |> Keyword.put_new(:ordered, false)

    enumerable
    |> Task.async_stream(&{key_fun.(&1), value_fun.(&1)}, opts)
    |> Enum.reduce(
      %{},
      fn
        {:ok, {key, value}}, acc ->
          Map.update(acc, key, [value], &List.insert_at(&1, -1, value))

        timeout_result, acc ->
          Map.update(
            acc,
            timeout_result,
            [timeout_result],
            &List.insert_at(&1, -1, timeout_result)
          )
      end
    )
  end

  def max_by(
        enumerable,
        fun,
        max_concurrency \\ System.schedulers_online(),
        sorter \\ &>=/2,
        empty_fallback \\ fn -> raise Enum.EmptyError end
      ) do
    opts = [timeout: :infinity, ordered: false, max_concurrency: max_concurrency]

    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
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

  def min_by(
        enumerable,
        fun,
        max_concurrency \\ System.schedulers_online(),
        sorter \\ &<=/2,
        empty_fallback \\ fn -> raise Enum.EmptyError end
      ) do
    opts = [timeout: :infinity, ordered: false, max_concurrency: max_concurrency]

    if Enum.empty?(enumerable) do
      empty_fallback.()
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
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
        max_concurrency \\ System.schedulers_online(),
        sorter_or_empty_fallback \\ &</2,
        empty_fallback \\ fn -> raise Enum.EmptyError end
      ) do
    opts = [timeout: :infinity, ordered: false, max_concurrency: max_concurrency]

    if Enum.empty?(enumerable) do
      if is_function(sorter_or_empty_fallback, 0) do
        sorter_or_empty_fallback.()
      else
        empty_fallback.()
      end
    else
      {{:ok, {_, min}}, {:ok, {_, max}}} =
        enumerable
        |> Task.async_stream(&{fun.(&1), &1}, opts)
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

  def sort_by(enumerable, fun, opts \\ [], sorter \\ &<=/2) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)
      |> Keyword.put_new(:ordered, false)

    if Enum.empty?(enumerable) do
      []
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
      |> Enum.sort_by(
        fn
          {:ok, {by, _}} ->
            by

          timeout_result ->
            timeout_result
        end,
        sorter
      )
      |> Enum.map(fn
        {:ok, {_, element}} -> element
        timeout_result -> timeout_result
      end)
    end
  end

  def split_while(enumerable, fun, max_concurrency \\ System.schedulers_online()) do
    enumerable
    |> Stream.chunk_every(max_concurrency)
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

  def split_with(enumerable, fun, opts \\ []) do
    opts =
      Keyword.validate!(opts, max_concurrency: System.schedulers_online(), ordered: true)
      |> Keyword.put(:timeout, :infinity)

    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, opts)
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

  def uniq_by(enumerable, fun, opts \\ []) do
    opts =
      Keyword.validate!(opts, max_concurrency: System.schedulers_online(), ordered: true)
      |> Keyword.put(:timeout, :infinity)

    if Enum.empty?(enumerable) do
      []
    else
      enumerable
      |> Task.async_stream(&{fun.(&1), &1}, opts)
      |> Stream.uniq_by(fn {:ok, {by, _}} ->
        by
      end)
      |> Stream.map(fn {:ok, {_, element}} -> element end)
    end
  end

  def zip_with(enumerables, fun, opts \\ []) do
    enumerables
    |> Stream.zip()
    |> map(fun, opts)
  end
end
