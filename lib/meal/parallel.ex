defmodule Meal.Parallel do
  defp exclude_exit(stream, opts) do
    if Keyword.get(opts, :exclude_exit) == true do
      Stream.flat_map(stream, fn
        {:ok, v} -> [v]
        _ -> []
      end)
    else
      stream
    end
  end

  defp default_opts() do
    [
      timeout: :infinity,
      on_timeout: :kill_task,
      ordered: true,
      zip_input_on_exit: false,
      exclude_exit: true
    ]
  end

  def map(enumerable, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    stream = Task.Supervisor.async_stream_nolink(Meal.Parallel.Supervisor, enumerable, fun, opts)

    exclude_exit(stream, opts)
  end

  def map_every(enumerable, nth, fun, opts \\ [])

  def map_every(enumerable, 0, fun, _), do: Stream.map_every(enumerable, 0, fun)

  def map_every(enumerable, nth, fun, opts) when is_integer(nth) and nth > 0 do
    opts = Keyword.merge(default_opts(), opts)

    stream =
      Task.Supervisor.async_stream_nolink(
        Meal.Parallel.Supervisor,
        Stream.with_index(enumerable),
        fn {element, index} ->
          if rem(index, nth) == 0 do
            fun.(element)
          else
            element
          end
        end,
        opts
      )

    exclude_exit(stream, opts)
  end

  def map_intersperse(enumerable, separator, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    enumerable
    |> map(fun, opts)
    |> Enum.map_intersperse(separator, & &1)
  end

  def map_join(enumerable, joiner \\ "", fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    enumerable
    |> map(fun, opts)
    |> Enum.map_join(joiner, & &1)
  end

  def flat_map(enumerable, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    stream = enumerable |> map(fun, opts)

    if Keyword.get(opts, :exclude_exit) == true do
      Stream.flat_map(stream, & &1)
    else
      stream
    end
  end

  def chunk_by(enumerable, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)
    opts = Keyword.put(opts, :zip_input_on_exit, true)

    stream = enumerable |> map(&{fun.(&1), &1}, opts)

    if Keyword.get(opts, :exclude_exit) == true do
      Stream.chunk_by(stream, fn {value, _} -> value end)
      |> Stream.map(fn chunk -> Enum.map(chunk, fn {_, elem} -> elem end) end)
    else
      Stream.chunk_by(stream, fn
        {:ok, {value, _}} -> value
        {:exit, {_, reason}} -> reason
      end)
      |> Stream.map(fn chunk ->
        Enum.map(chunk, fn
          {:ok, {_, elem}} -> {:ok, elem}
          exit_item -> exit_item
        end)
      end)
    end
  end

  def each(enumerable, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    Task.Supervisor.async_stream_nolink(Meal.Parallel.Supervisor, enumerable, fun, opts)
    |> Stream.run()

    :ok
  end

  def filter(enumerable, fun, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)
    opts = Keyword.put(opts, :zip_input_on_exit, true)

    stream = enumerable |> map(&{fun.(&1), &1}, opts)

    if Keyword.get(opts, :exclude_exit) == true do
      Stream.filter(stream, fn {value, _} -> value end)
      |> Stream.map(fn {_, elem} -> elem end)
    else
      Stream.filter(stream, fn
        {:ok, {value, _}} -> value
        _ -> true
      end)
      |> Stream.map(fn
        {:ok, {_, elem}} -> {:ok, elem}
        exit_item -> exit_item
      end)
    end
  end

  def reject(enumerable, fun, opts \\ []) do
    filter(enumerable, &(!fun.(&1)), opts)
  end

  def find(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts = Keyword.merge(default_opts(), opts)

    Task.Supervisor.async_stream_nolink(
      Meal.Parallel.Supervisor,
      enumerable,
      &{fun.(&1), &1},
      opts
    )
    |> Enum.find(:not_found, fn
      {:ok, {value, _}} -> value
      _ -> false
    end)
    |> then(fn
      :not_found -> default
      {:ok, {_, element}} -> element
    end)
  end

  def find_value(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts = Keyword.merge(default_opts(), opts)

    Task.Supervisor.async_stream_nolink(
      Meal.Parallel.Supervisor,
      enumerable,
      &{fun.(&1), &1},
      opts
    )
    |> Enum.find_value(:not_found, fn
      {:ok, {value, _}} -> if value, do: {:ok, value}, else: false
      _ -> false
    end)
    |> then(fn
      {:ok, value} -> value
      :not_found -> default
    end)
  end

  def find_index(enumerable, fun, opts \\ []) when is_function(fun, 1) do
    enumerable
    |> Stream.with_index()
    |> find(nil, fn {element, _} -> fun.(element) end, opts)
    |> then(fn
      nil -> nil
      {_, index} -> index
    end)
  end

  def zip_with(enumerables, fun, opts \\ []) do
    enumerables
    |> Stream.zip_with(& &1)
    |> map(fun, opts)
  end

  def zip_with2(enum1, enum2, fun, opts \\ []) do
    zip_with([enum1, enum2], fun, opts)
  end
end
