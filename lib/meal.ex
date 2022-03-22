defmodule Meal do
  @break_label :break_5bae
  @continue_label :continue_5bae

  defmacro block(do: do_clause) do
    quote do
      try do
        unquote(do_clause)
      catch
        unquote(@break_label) -> nil
        {unquote(@break_label), var} -> var
      end
    end
  end

  defmacro loop(do: do_clause) do
    quote do
      try do
        for _ <- Stream.cycle([1]) do
          try do
            unquote(do_clause)
          catch
            unquote(@continue_label) -> nil
          end
        end
      catch
        unquote(@break_label) -> nil
        {unquote(@break_label), var} -> var
      end
    end
  end

  defmacro continue() do
    quote do
      throw(unquote(@continue_label))
    end
  end

  defmacro continue_if(do: do_clause) do
    quote do
      if(unquote(do_clause), do: Meal.continue())
    end
  end

  defmacro continue_if(clause) do
    quote do
      if(unquote(clause), do: Meal.continue())
    end
  end

  defmacro continue_unless(do: do_clause) do
    quote do
      Meal.continue_if(do: !unquote(do_clause))
    end
  end

  defmacro continue_unless(clause) do
    quote do
      Meal.continue_if(!unquote(clause))
    end
  end

  defmacro break() do
    quote do
      throw(unquote(@break_label))
    end
  end

  defmacro break(res) do
    quote do
      throw({unquote(@break_label), unquote(res)})
    end
  end

  defmacro break(res, if: if_clause) do
    quote do
      if(unquote(if_clause), do: throw({unquote(@break_label), unquote(res)}))
    end
  end

  defmacro break(res, unless: unless_clause) do
    quote do
      Meal.break(unquote(res), if: !unquote(unless_clause))
    end
  end

  defmacro break_if(do: do_clause) do
    quote do
      if(unquote(do_clause), do: Meal.break())
    end
  end

  defmacro break_if(clause) do
    quote do
      if(unquote(clause), do: Meal.break())
    end
  end

  defmacro break_unless(do: do_clause) do
    quote do
      Meal.break_if(!unquote(do_clause))
    end
  end

  defmacro break_unless(clause) do
    quote do
      Meal.break_if(!unquote(clause))
    end
  end

  defmacro while(condition, do: do_clause, else: else_clause) do
    quote do
      Meal.loop do
        if(unquote(condition)) do
          unquote(do_clause)
        else
          Meal.break(unquote(else_clause))
        end
      end
    end
  end

  defmacro while(condition, do: do_clause) do
    quote do
      Meal.while(unquote(condition), do: unquote(do_clause), else: nil)
    end
  end

  defmacro until(condition, do: do_clause, else: else_clause) do
    quote do
      Meal.while(!unquote(condition), do: unquote(do_clause), else: unquote(else_clause))
    end
  end

  defmacro until(condition, do: do_clause) do
    quote do
      Meal.until(unquote(condition), do: unquote(do_clause), else: nil)
    end
  end

  def p(term, opts \\ [charlists: :as_lists, limit: :infinity, printable_limit: :infinity]) do
    IO.inspect(term, opts)
  end

  def normalize_index(enumerable, index) when is_integer(index) do
    size = Enum.count(enumerable)
    if index >= 0, do: index, else: index + size
  end

  def normalize_index(enumerable, first..last) do
    normalize_index(enumerable, first)..normalize_index(enumerable, last)
  end

  def enumerable?(element) do
    case Enumerable.impl_for(element) do
      nil -> false
      _ -> true
    end
  end

  def enumerable_wrap(element) do
    case Enumerable.impl_for(element) do
      nil -> [element]
      _ -> element
    end
  end

  def flatten(deep_enumerable, level \\ -1, tail \\ []) do
    if enumerable?(deep_enumerable) do
      case level do
        n when is_integer(n) and n < 0 ->
          _flatten(deep_enumerable, [])

        0 ->
          Enum.to_list(deep_enumerable)

        n when is_integer(n) and n > 0 ->
          Enum.reduce(1..n, deep_enumerable, fn _, acc ->
            _flat_one_level(acc)
          end)
      end
      |> Enum.concat(enumerable_wrap(tail))
    else
      raise "can not faltten #{deep_enumerable}, it must be enumerable"
    end
  end

  defp _flatten(deep_enumerable, result_list) do
    case Enum.split(deep_enumerable, 1) do
      {[e], rest} ->
        if enumerable?(e) do
          _flatten(_flat_one_level(e) ++ rest, result_list)
        else
          _flatten(rest, [e | result_list])
        end

      {[], []} ->
        Enum.reverse(result_list)
    end
  end

  defp _flat_one_level(enumerable) do
    Enum.flat_map(enumerable, fn e -> enumerable_wrap(e) end)
  end

  defguard is_pos_integer(int) when is_integer(int) and int > 0

  defguard is_non_neg_integer(int) when is_integer(int) and int >= 0

  defguard is_neg_integer(int) when is_integer(int) and int < 0

  defguard is_even(int) when is_integer(int) and rem(int, 2) == 0

  defguard is_odd(int) when is_integer(int) and rem(int, 2) == 1

  defguard is_falsy(term) when term in [false, nil]

  defguard is_truthy(term) when term not in [false, nil]

  def curry(fun) when is_function(fun) do
    {:arity, arity} = Function.info(fun, :arity)

    get_curry_string = fn arity ->
      args_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"
      apply_str = "apply(fun, #{args_str})"

      Enum.reduce(
        arity..1//-1,
        "fn -> #{apply_str} end",
        fn i, acc ->
          "fn arg#{i} -> #{acc} end"
        end
      )
    end

    get_curry_string.(arity)
    |> Code.eval_string(fun: fun)
    |> elem(0)
  end

  def curry_r(fun) when is_function(fun) do
    {:arity, arity} = Function.info(fun, :arity)

    get_curry_string = fn arity ->
      args_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"
      apply_str = "apply(fun, #{args_str})"

      Enum.reduce(
        1..arity//1,
        "fn -> #{apply_str} end",
        fn i, acc ->
          "fn arg#{i} -> #{acc} end"
        end
      )
    end

    get_curry_string.(arity)
    |> Code.eval_string(fun: fun)
    |> elem(0)
  end

  def partial_apply(fun, args_map) when is_function(fun) and is_map(args_map) do
    {:arity, arity} = Function.info(fun, :arity)

    case arity do
      0 ->
        fun.()

      arity ->
        args_map =
          Enum.reduce(
            1..arity,
            %{args_call_list: []},
            fn i, acc ->
              case Map.fetch(args_map, i) do
                {:ok, arg} -> Map.put(acc, String.to_atom("arg#{i}"), arg)
                :error -> Map.update(acc, :args_call_list, [], &["arg#{i}" | &1])
              end
            end
          )

        args_apply_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"

        code =
          case Enum.reverse(args_map.args_call_list)
               |> Enum.join(",") do
            "" -> "apply(fun, #{args_apply_str})"
            args -> "fn #{args} -> apply(fun, #{args_apply_str}) end"
          end

        args_map =
          Map.delete(args_map, :args_call_list)
          |> Map.put(:fun, fun)

        code
        |> Code.eval_string(Map.to_list(args_map))
        |> elem(0)
    end
  end
end

defmodule Meal.Factorial do
  def of(0), do: 1
  def of(n) when is_integer(n) and n > 0, do: _of(n, n - 1)

  defp _of(acc, 0), do: acc
  defp _of(acc, n), do: _of(acc * n, n - 1)
end

defimpl Enumerable, for: Tuple do
  def count(tuple) do
    {:ok, tuple_size(tuple)}
  end

  def member?(_tuple, _element) do
    {:error, __MODULE__}
  end

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(tuple, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(tuple, &1, fun)}
  def reduce({}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(tuple, {:cont, acc}, fun),
    do: reduce(Tuple.delete_at(tuple, 0), fun.(elem(tuple, 0), acc), fun)

  def slice(tuple) do
    size = tuple_size(tuple)

    slice_fun = fn start, length
                   when start >= 0 and start < size and length >= 1 and start + length <= size ->
      for i <- start..(start + length - 1), into: [] do
        elem(tuple, i)
      end
    end

    {:ok, size, slice_fun}
  end
end

defimpl Collectable, for: Tuple do
  def into(tuple) do
    collector_fun = fn
      acc, {:cont, elem} -> Tuple.append(acc, elem)
      acc, :done -> acc
      _, :halt -> :ok
    end

    {tuple, collector_fun}
  end
end
