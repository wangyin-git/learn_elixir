defmodule Meal.Queue do
  require Meal
  alias __MODULE__

  defstruct __queue__: :queue.new()

  def new() do
    %Queue{}
  end

  def from_list(list) when is_list(list) do
    %Queue{__queue__: :queue.from_list(list)}
  end

  def from_enumerable(enumerable) do
    if !Meal.Enum.enumerable?(enumerable) do
      raise "can not create #{__MODULE__} from #{enumerable}"
    end

    enumerable
    |> Enum.to_list()
    |> from_list()
  end

  def from_erlang_queue(queue) do
    if :queue.is_queue(queue) do
      %Queue{__queue__: queue}
    else
      raise "can not create #{__MODULE__} from #{queue}"
    end
  end

  def delete(%Queue{__queue__: queue}, item) do
    :queue.delete(item, queue)
    |> from_erlang_queue()
  end

  def delete_r(%Queue{__queue__: queue}, item) do
    :queue.delete_r(item, queue)
    |> from_erlang_queue()
  end

  def delete_by(%Queue{__queue__: queue}, fun) when is_function(fun, 1) do
    :queue.delete_with(&Meal.is_truthy(fun.(&1)), queue)
    |> from_erlang_queue()
  end

  def delete_by_r(%Queue{__queue__: queue}, fun) when is_function(fun, 1) do
    :queue.delete_with_r(&Meal.is_truthy(fun.(&1)), queue)
    |> from_enumerable()
  end

  def filter(%Queue{__queue__: queue}, fun) when is_function(fun, 1) do
    :queue.filter(&Meal.is_truthy(fun.(&1)), queue)
    |> from_erlang_queue()
  end

  def map(%Queue{__queue__: queue}, fun) when is_function(fun, 1) do
    :queue.filtermap(&{true, fun.(&1)}, queue)
    |> from_erlang_queue()
  end

  def flat_map(%Queue{__queue__: queue}, fun) when is_function(fun, 1) do
    :queue.filter(
      fn item ->
        fun.(item)
        |> Enum.to_list()
      end,
      queue
    )
    |> from_erlang_queue()
  end

  def length(%Queue{__queue__: queue}) do
    :queue.len(queue)
  end

  def enq(%Queue{__queue__: queue}, item) do
    :queue.in(item, queue)
    |> from_erlang_queue()
  end

  def enq_r(%Queue{__queue__: queue}, item) do
    :queue.in_r(item, queue)
    |> from_erlang_queue()
  end

  def deq(%Queue{__queue__: queue}) do
    case :queue.out(queue) do
      {{:value, item}, q} -> {item, from_erlang_queue(q)}
      {:empty, _} -> :empty
    end
  end

  def deq_r(%Queue{__queue__: queue}) do
    case :queue.out_r(queue) do
      {{:value, item}, q} -> {item, from_erlang_queue(q)}
      {:empty, _} -> :empty
    end
  end

  def peek(%Queue{__queue__: queue}) do
    case :queue.peek(queue) do
      {:value, item} -> {:ok, item}
      :empty -> :empty
    end
  end

  def peek_r(%Queue{__queue__: queue}) do
    case :queue.peek_r(queue) do
      {:value, item} -> {:ok, item}
      :empty -> :empty
    end
  end

  def join(%Queue{__queue__: queue1}, %Queue{__queue__: queue2}) do
    :queue.join(queue1, queue2)
    |> from_erlang_queue()
  end

  def reverse(%Queue{__queue__: queue}) do
    :queue.reverse(queue)
    |> from_erlang_queue()
  end

  def split(%Queue{__queue__: queue}, n) when Meal.is_non_neg_integer(n) do
    try do
      :queue.split(n, queue)
      |> then(fn {q1, q2} -> {from_erlang_queue(q1), from_erlang_queue(q2)} end)
    rescue
      ArgumentError -> {from_erlang_queue(queue), new()}
    end
  end

  def to_list(%Queue{__queue__: queue}) do
    :queue.to_list(queue)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%Queue{} = queue, opts) do
      concat(["##{@for}", to_doc(Queue.to_list(queue), opts)])
    end
  end

  defimpl Enumerable do
    def count(%Queue{__queue__: queue}) do
      empty_queue = :queue.new()

      if match?(^empty_queue, queue) do
        {:ok, 0}
      else
        {:error, __MODULE__}
      end
    end

    def member?(%Queue{__queue__: queue}, _element) do
      empty_queue = :queue.new()

      if match?(^empty_queue, queue) do
        {:ok, false}
      else
        {:error, __MODULE__}
      end
    end

    def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
    def reduce(queue, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(queue, &1, fun)}

    def reduce(%Queue{__queue__: queue_} = queue, {:cont, acc}, fun) do
      if :queue.is_empty(queue_) do
        {:done, acc}
      else
        reduce(elem(Queue.deq(queue), 1), fun.(elem(Queue.peek(queue), 1), acc), fun)
      end
    end

    def slice(%Queue{__queue__: queue}) do
      empty_queue = :queue.new()

      if match?(^empty_queue, queue) do
        {:ok, 0, fn _, _ -> [] end}
      else
        {:error, __MODULE__}
      end
    end
  end

  defimpl Collectable do
    def into(%Queue{} = queue) do
      collector_fun = fn
        acc, {:cont, elem} -> Queue.enq(acc, elem)
        acc, :done -> acc
        _, :halt -> :ok
      end

      {queue, collector_fun}
    end
  end
end
