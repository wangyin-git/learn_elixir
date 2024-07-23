defmodule Meal.Iterator do
  @enforce_keys [:iterable]
  defstruct [:iterable]

  def new(iterable) do
    unless Meal.impl_protocol?(iterable, Meal.Iterable) do
      raise ArgumentError,
            "Argument of #{__MODULE__}.new/1 must implement Meal.Iterable"
    end

    %Meal.Iterator{iterable: iterable}
  end

  def next(%Meal.Iterator{iterable: iterable}, opts \\ [timeout: :infinity]) do
    Meal.Iterable.next(iterable, opts)
  end

  def peek(%Meal.Iterator{iterable: iterable}, opts \\ [timeout: :infinity]) do
    Meal.Iterable.peek(iterable, opts)
  end

  def end?(%Meal.Iterator{} = iter) do
    peek(iter) == :end
  end
end

defimpl Enumerable, for: Meal.Iterator do
  alias Meal.Iterator

  def count(%Iterator{} = iter) do
    if Iterator.end?(iter) do
      {:ok, 0}
    else
      {:error, __MODULE__}
    end
  end

  def member?(%Iterator{} = iter, _element) do
    if Iterator.end?(iter) do
      {:ok, false}
    else
      {:error, __MODULE__}
    end
  end

  def slice(%Iterator{} = iter) do
    if Iterator.end?(iter) do
      {:ok, 0, fn _, _ -> [] end}
    else
      {:error, __MODULE__}
    end
  end

  def reduce(_iter, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(iter, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iter, &1, fun)}

  def reduce(%Iterator{} = iter, {:cont, acc}, fun) do
    if Iterator.end?(iter) do
      {:done, acc}
    else
      {:ok, head} = Iterator.next(iter)
      reduce(iter, fun.(head, acc), fun)
    end
  end
end

defprotocol Meal.Iterable do
  def next(iterable, opts)

  def peek(iterable, opts)
end

defmodule Meal.Enumerable_To_Iterable do
  @enforce_keys [:task]
  defstruct [:task]

  def new(enumerable) do
    unless Meal.impl_protocol?(enumerable, Enumerable) do
      raise ArgumentError,
            "Argument for Meal.Enumerable_To_Iterable.new/1 must implement Enumerable protocol"
    end

    task =
      Task.async(fn ->
        f = fn f, element ->
          receive do
            {:next, from, ref} ->
              send(from, {:reply_for_next, ref, {:ok, element}})

            {:peek, from, ref} ->
              send(from, {:reply_for_peek, ref, {:ok, element}})
              f.(f, element)

            msg ->
              raise "Invalid message #{inspect(msg)} for #{__MODULE__}"
          end
        end

        for element <- enumerable do
          f.(f, element)
        end

        f = fn f ->
          receive do
            {:next, from, ref} ->
              send(from, {:reply_for_next, ref, :end})
              f.(f)

            {:peek, from, ref} ->
              send(from, {:reply_for_peek, ref, :end})
              f.(f)

            msg ->
              raise "Invalid message #{inspect(msg)} for #{__MODULE__}"
          end
        end

        f.(f)
      end)

    %__MODULE__{task: task}
  end

  def shutdown(%Meal.Enumerable_To_Iterable{task: task}) do
    Task.shutdown(task, :brutal_kill)
  end
end

defimpl Meal.Iterable, for: Meal.Enumerable_To_Iterable do
  def next(%Meal.Enumerable_To_Iterable{task: task}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    %Task{pid: pid, ref: ref} = task
    send(pid, {:next, self(), ref})

    receive do
      {:reply_for_next, ^ref, :end} -> :end
      {:reply_for_next, ^ref, {:ok, element}} -> {:ok, element}
    after
      timeout -> raise "#{__MODULE__}.next/1 timeout"
    end
  end

  def peek(%Meal.Enumerable_To_Iterable{task: task}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    %Task{pid: pid, ref: ref} = task
    send(pid, {:peek, self(), ref})

    receive do
      {:reply_for_peek, ^ref, :end} -> :end
      {:reply_for_peek, ^ref, {:ok, element}} -> {:ok, element}
    after
      timeout -> raise "#{__MODULE__}.peek/1 timeout"
    end
  end
end
