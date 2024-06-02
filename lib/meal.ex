defmodule Meal do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Meal.Worker.start_link(arg)
      # {Meal.Worker, arg}
      {Task.Supervisor, name: Meal.Parallel.Supervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Meal.Supervisor]
    Supervisor.start_link(children, opts)
  end

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

  defmacro block(label, do: do_clause) when is_atom(label) do
    quote do
      try do
        unquote(do_clause)
      catch
        unquote(label) -> nil
        {unquote(label), var} -> var
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

  defmacro break(label: label) when is_atom(label) do
    quote do
      throw(unquote(label))
    end
  end

  defmacro break(res) do
    quote do
      throw({unquote(@break_label), unquote(res)})
    end
  end

  defmacro break(res, label: label) when is_atom(label) do
    quote do
      throw({unquote(label), unquote(res)})
    end
  end

  defmacro break(res, if: if_clause) do
    quote do
      if(unquote(if_clause), do: throw({unquote(@break_label), unquote(res)}))
    end
  end

  defmacro break(res, if: if_clause, label: label) when is_atom(label) do
    quote do
      if(unquote(if_clause), do: throw({unquote(label), unquote(res)}))
    end
  end

  defmacro break(res, unless: unless_clause) do
    quote do
      Meal.break(unquote(res), if: !unquote(unless_clause))
    end
  end

  defmacro break(res, unless: unless_clause, label: label) when is_atom(label) do
    quote do
      Meal.break(unquote(res), if: !unquote(unless_clause), label: label)
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

  defmacro break_if(label, do: do_clause) when is_atom(label) do
    quote do
      if(unquote(do_clause), do: Meal.break(label: label))
    end
  end

  defmacro break_if(clause, label: label) when is_atom(label) do
    quote do
      if(unquote(clause), do: Meal.break(label: label))
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

  defmacro break_unless(label, do: do_clause) when is_atom(label) do
    quote do
      Meal.break_if(!unquote(do_clause), label: label)
    end
  end

  defmacro break_unless(clause, label: label) when is_atom(label) do
    quote do
      Meal.break_if(!unquote(clause), label: label)
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

  def p(term, opts \\ []) do
    opts =
      Keyword.put_new(opts, :charlists, :as_lists)
      |> Keyword.put_new(:limit, :infinity)
      |> Keyword.put_new(:printable_limit, :infinity)

    IO.inspect(term, opts)
  end

  def impl_protocol?(element, protocol) do
    Protocol.assert_protocol!(protocol)

    case protocol.impl_for(element) do
      nil -> false
      _ -> true
    end
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

    get_curry_string = fn
      0 ->
        "fn -> fun.() end"

      arity ->
        args_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"
        apply_str = "apply(fun, #{args_str})"

        Enum.reduce(
          arity..1//-1,
          apply_str,
          fn i, acc ->
            "fn arg#{i} -> #{acc} end"
          end
        )
    end

    get_curry_string.(arity)
    |> Code.eval_string(fun: fun)
    |> elem(0)
  end

  def curry_to_void(fun) when is_function(fun) do
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

    get_curry_string = fn
      0 ->
        "fn -> fun.() end"

      arity ->
        args_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"
        apply_str = "apply(fun, #{args_str})"

        Enum.reduce(
          1..arity//1,
          apply_str,
          fn i, acc ->
            "fn arg#{i} -> #{acc} end"
          end
        )
    end

    get_curry_string.(arity)
    |> Code.eval_string(fun: fun)
    |> elem(0)
  end

  def curry_r_to_void(fun) when is_function(fun) do
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
        fun

      arity ->
        {args_map, args_call_list} =
          Enum.reduce(
            1..arity,
            {%{}, []},
            fn i, {map, list} ->
              case Map.fetch(args_map, i) do
                {:ok, arg} -> {Map.put(map, String.to_atom("arg#{i}"), arg), list}
                :error -> {map, ["arg#{i}" | list]}
              end
            end
          )

        args_apply_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"

        code =
          case Enum.reverse(args_call_list)
               |> Enum.join(",") do
            "" -> "fn -> apply(fun, #{args_apply_str}) end"
            args -> "fn #{args} -> apply(fun, #{args_apply_str}) end"
          end

        args_map = Map.put(args_map, :fun, fun)

        code
        |> Code.eval_string(Map.to_list(args_map))
        |> elem(0)
    end
  end
end
