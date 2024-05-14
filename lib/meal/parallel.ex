defmodule Meal.Parallel do
  def map(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> then(fn stream ->
      case Keyword.get(opts, :timeout) do
        :infinity ->
          stream |> Stream.map(fn {:ok, v} -> v end)

        _ ->
          stream
          |> Stream.map(fn
            {:ok, v} -> {:ok, v}
            {:exit, :timeout} -> :timeout
          end)
      end
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
    |> then(fn stream ->
      case Keyword.get(opts, :timeout) do
        :infinity ->
          stream |> Stream.map(fn {:ok, v} -> v end)

        _ ->
          stream
          |> Stream.map(fn
            {:ok, v} -> {:ok, v}
            {:exit, :timeout} -> :timeout
          end)
      end
    end)
  end

  def map_intersperse(enumerable, separator, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> then(fn stream ->
      case Keyword.get(opts, :timeout) do
        :infinity ->
          stream |> Stream.map(fn {:ok, v} -> v end)

        _ ->
          stream
          |> Stream.map(fn
            {:ok, v} -> {:ok, v}
            {:exit, :timeout} -> :timeout
          end)
      end
    end)
    |> Enum.map_intersperse(separator, & &1)
  end

  def map_join(enumerable, joiner \\ "", fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> then(fn stream ->
      case Keyword.get(opts, :timeout) do
        :infinity ->
          stream |> Stream.map(fn {:ok, v} -> v end)

        _ ->
          stream
          |> Stream.map(fn
            {:ok, v} -> "{:ok, #{v}}"
            {:exit, :timeout} -> :timeout
          end)
      end
    end)
    |> Enum.map_join(joiner, & &1)
  end

  def flat_map(enumerable, fun, opts \\ []) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(fun, opts)
    |> then(fn stream ->
      case Keyword.get(opts, :timeout) do
        :infinity ->
          stream |> Stream.map(fn {:ok, v} -> v end)

        _ ->
          stream
          |> Stream.map(fn
            {:ok, v} -> [{:ok, Meal.Enum.flatten(v, 1)}]
            {:exit, :timeout} -> [:timeout]
          end)
      end
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
        {:ok, {_, element}} ->
          case Keyword.get(opts, :timeout) do
            :infinity -> element
            _ -> {:ok, element}
          end

        {:exit, :timeout} ->
          :timeout
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
      {:ok, {_, element}} ->
        case Keyword.get(opts, :timeout) do
          :infinity -> element
          _ -> {:ok, element}
        end

      {:exit, :timeout} ->
        :timeout
    end)
  end

  def reject(enumerable, fun, opts \\ []) do
    filter(enumerable, &(!fun.(&1)), opts)
  end

  def find(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

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
  end

  def find_value(enumerable, default \\ nil, fun, opts \\ []) when is_function(fun, 1) do
    opts =
      Keyword.put_new(opts, :timeout, :infinity)
      |> Keyword.put_new(:on_timeout, :kill_task)

    enumerable
    |> Task.async_stream(&{fun.(&1), &1}, opts)
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
    |> Stream.zip()
    |> map(fun, opts)
  end
end
