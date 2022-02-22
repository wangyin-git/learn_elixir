defmodule Meal do
  @break_label :break_5bae
  @continue_label :continue_5bae

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
      throw unquote(@continue_label)
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
      throw unquote(@break_label)
    end
  end

  defmacro break(res) do
    quote do
      throw {unquote(@break_label), unquote(res)}
    end
  end

  defmacro break(res, if: if_clause) do
    quote do
      if(unquote(if_clause), do: throw {unquote(@break_label), unquote(res)})
    end
  end

  defmacro break(res, unless: unless_clause) do
    quote do
      Meal.break(unquote(res), if: !(unquote(unless_clause)))
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
      Meal.while(!(unquote(condition)), do: unquote(do_clause), else: unquote(else_clause))
    end
  end

  defmacro until(condition, do: do_clause) do
    quote do
      Meal.until(unquote(condition), do: unquote(do_clause), else: nil)
    end
  end

  def p(term) do
    IO.inspect(term)
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
    |> Code.eval_string([fun: fun])
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
    |> Code.eval_string([fun: fun])
    |> elem(0)
  end

  def partial_apply(fun, args_map) when is_function(fun) and is_map(args_map) do
    if !Enum.all?(args_map, fn {key, _} -> is_integer(key) && key > 0 end) do
      raise "map keys must be all positive integer"
    end
    {:arity, arity} = Function.info(fun, :arity)
    case arity do
      0 -> fun.()
      arity ->
        args_map = Enum.reduce(
          1..arity,
          %{args_call_list: []},
          fn i, acc ->
            case Map.fetch(args_map, i) do
              {:ok, arg} -> Map.put(acc, String.to_atom("arg#{i}"), arg)
              :error -> Map.update(acc, :args_call_list, [], &(["arg#{i}" | &1]))
            end
          end
        )

        args_apply_str = "[" <> Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1))) <> "]"

        code = case Enum.reverse(args_map.args_call_list)
                    |> Enum.join(",") do
          "" -> "apply(fun, #{args_apply_str})"
          args -> "fn #{args} -> apply(fun, #{args_apply_str}) end"
        end

        args_map = Map.delete(args_map, :args_call_list)
                   |> Map.put(:fun, fun)

        code
        |> Code.eval_string(Map.to_list(args_map))
        |> elem(0)
    end
  end
end

defmodule Meal.Iterator do
  @enforce_keys [:agent, :enumerable]
  defstruct [:agent, :enumerable]

  def new(enumerable) do
    {:ok, pid} = Agent.start(fn -> enumerable end)
    %Meal.Iterator{agent: pid, enumerable: enumerable}
  end

  def next(%Meal.Iterator{agent: agent}) do
    Agent.get_and_update(
      agent,
      fn enumerable ->
        if Enum.empty?(enumerable) do
          {:end, []}
        else
          {{:ok, Enum.at(enumerable, 0)}, Enum.drop(enumerable, 1)}
        end
      end,
      :infinity
    )
  end

  def peek(%Meal.Iterator{agent: agent}) do
    Agent.get(
      agent,
      fn enumerable ->
        if Enum.empty?(enumerable) do
          :end
        else
          {:ok, Enum.at(enumerable, 0)}
        end
      end,
      :infinity
    )
  end

  def rewind(%Meal.Iterator{agent: agent, enumerable: enumerable}) do
    Agent.update(
      agent,
      fn _ ->
        enumerable
      end,
      :infinity
    )
  end

  def stop(%Meal.Iterator{agent: agent}) do
    code = quote do
      if Process.alive?(unquote(agent)) do
        Agent.stop(unquote(agent))
      else
        :iterator_already_stopped
      end
    end
    Meal.ExecuteServer.send(code: code, binding: [])
  end

  def end?(%Meal.Iterator{} = iter) do
    peek(iter) == :end
  end
end

defimpl Enumerable, for: Meal.Iterator do
  alias Meal.Iterator

  def count(%Iterator{}) do
    {:error, __MODULE__}
  end

  def member?(%Iterator{}, _element) do
    {:error, __MODULE__}
  end

  def slice(%Iterator{}) do
    {:error, __MODULE__}
  end

  def reduce(_iter, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(iter, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(iter, &1, fun)}
  def reduce(%Iterator{} = iter, {:cont, acc}, fun) do
    if Iterator.end?(iter) do
      {:done, acc}
    else
      head = Iterator.next(iter)
             |> elem(1)
      reduce(iter, fun.(head, acc), fun)
    end
  end
end

defmodule Meal.ExecuteServer do
  @pid_name :execute_server
  @on_load :start_execute_server
  defp start_execute_server do
    Process.register(
      spawn(
        fn ->
          require Meal
          Meal.loop do
            receive do
              {code, binding} ->
                case code do
                  code when is_binary(code) -> Code.eval_string(code, binding, __ENV__)
                  code -> Code.eval_quoted(code, binding, __ENV__)
                end
            end
          end
        end
      ),
      @pid_name
    )
    :ok
  end

  def send(code: code) do
    send(code: code, binding: [], async: false)
  end

  def send(code: code, binding: binding) do
    send(code: code, binding: binding, async: false)
  end

  def send(code: code, binding: binding, async: false) when is_binary(code) do
    code_ = """
    send(self_pid__, {Meal.ExecuteServer.ExecuteResult, #{code}})
    """
    Kernel.send(@pid_name, {code_, Keyword.merge(binding, [self_pid__: self()])})
    receive do
      {Meal.ExecuteServer.ExecuteResult, result} -> result
    end
  end

  def send(code: code, binding: binding, async: false) do
    code_ = quote do
      send(unquote(self()), {Meal.ExecuteServer.ExecuteResult, unquote(code)})
    end
    Kernel.send(@pid_name, {code_, binding})
    receive do
      {Meal.ExecuteServer.ExecuteResult, result} -> result
    end
  end

  def send(code: code, binding: binding, async: true) do
    Kernel.send(@pid_name, {code, binding})
    :ok
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
    tuple_size(tuple)
  end

  def member?(_tuple, _element) do
    {:error, __MODULE__}
  end

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(tuple, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(tuple, &1, fun)}
  def reduce({}, {:cont, acc}, _fun), do: {:done, acc}
  def reduce(tuple, {:cont, acc}, fun), do: reduce(Tuple.delete_at(tuple, 0), fun.(elem(tuple, 0), acc), fun)

  def slice(tuple) do
    size = tuple_size(tuple)
    slice_fun = fn (start, length) when start >= 0 and start < size and length >= 1 and start + length <= size ->
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
      (acc, {:cont, elem}) -> Tuple.append(acc, elem)
      (acc, :done) -> acc
      (_, :halt) -> :ok
    end
    {tuple, collector_fun}
  end
end

defmodule Meal.Parallel do
  def map(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_map, fun.(&1)}) end)))
    |> Enum.map(&(receive do: ({^&1, :parallel_map, result} -> result)))
  end

  def map_every(enumerable, nth, fun) do
    self = self()
    enumerable
    |> Enum.map_every(nth, &(spawn_link(fn -> send(self, {self(), :parallel_map_every, fun.(&1)}) end)))
    |> Enum.map_every(nth, &(receive do: ({^&1, :parallel_map_every, result} -> result)))
  end

  def map_intersperse(enumerable, separator, fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_map_intersperse, fun.(&1)}) end)))
    |> Enum.map_intersperse(separator, &(receive do: ({^&1, :parallel_map_intersperse, result} -> result)))
  end

  def map_join(enumerable, joiner \\ "", fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_map_join, fun.(&1)}) end)))
    |> Enum.map_join(joiner, &(receive do: ({^&1, :parallel_map_join, result} -> result)))
  end

  def flat_map(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_flat_map, fun.(&1)}) end)))
    |> Enum.flat_map(&(receive do: ({^&1, :parallel_flat_map, result} -> result)))
  end

  def chunk_by(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_chunk_by, fun.(&1), &1}) end)))
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
    |> then(
         fn
           {_, [], chunks} -> chunks
           {_, chunk, chunks} -> [Enum.reverse(chunk) | chunks]
         end
       )
    |> Enum.reverse()
  end

  def each(enumerable, fun) do
    map(enumerable, fun)
    :ok
  end

  def filter(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_filter, fun.(&1), &1}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_reject, fun.(&1), &1}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_find, fun.(&1), &1}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_find_index, fun.(&1)}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_find_value, fun.(&1)}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_frequencies_by, fun.(&1)}) end)))
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
    |> Enum.map(&(spawn_link(fn -> send(self, {self(), :parallel_group_by, [key_fun.(&1), value_fun.(&1)]}) end)))
    |> Enum.reduce(
         %{},
         fn pid, acc ->
           receive do
             {^pid, :parallel_group_by, [key, value]} ->
               Map.update(acc, key, [value], &(List.insert_at(&1, -1, value)))
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
      |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_max_by, fun.(&1)}) end), &1}))
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
      |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_min_by, fun.(&1)}) end), &1}))
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
      {{_, min}, {_, max}} = enumerable
                             |> Enum.map(
                                  &({spawn_link(fn -> send(self, {self(), :parallel_min_max_by, fun.(&1)}) end), &1})
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
      |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_sort_by, fun.(&1)}) end), &1}))
      |> Enum.sort_by(
           fn {pid, _} ->
             receive do
               {^pid, :parallel_sort_by, result} -> result
             end
           end,
           sorter
         )
      |> Enum.map(&(elem(&1, 1)))
    end
  end

  def split_while(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_split_while, fun.(&1)}) end), &1}))
    |> Enum.split_while(
         fn {pid, _} ->
           receive do
             {^pid, :parallel_split_while, result} -> result
           end
         end
       )
    |> then(
         fn {list1, list2} ->
           {
             get_in(list1, [Access.all(), Access.elem(1)]),
             get_in(list2, [Access.all(), Access.elem(1)])
           }
         end
       )
  end

  def split_with(enumerable, fun) do
    self = self()
    enumerable
    |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_split_with, fun.(&1)}) end), &1}))
    |> Enum.split_with(
         fn {pid, _} ->
           receive do
             {^pid, :parallel_split_with, result} -> result
           end
         end
       )
    |> then(
         fn {list1, list2} ->
           {
             get_in(list1, [Access.all(), Access.elem(1)]),
             get_in(list2, [Access.all(), Access.elem(1)])
           }
         end
       )
  end

  def uniq_by(enumerable, fun) do
    if Enum.empty?(enumerable) do
      []
    else
      self = self()
      enumerable
      |> Enum.map(&({spawn_link(fn -> send(self, {self(), :parallel_uniq_by, fun.(&1)}) end), &1}))
      |> Enum.uniq_by(
           fn {pid, _} ->
             receive do
               {^pid, :parallel_uniq_by, result} -> result
             end
           end
         )
      |> Enum.map(&(elem(&1, 1)))
    end
  end

  def zip_with(enumerables, fun) do
    self = self()
    enumerables
    |> Enum.zip_with(&(spawn_link(fn -> send(self, {self(), :parallel_zip_with, fun.(&1)}) end)))
    |> Enum.map(&(receive do: ({^&1, :parallel_zip_with, result} -> result)))
  end

  def zip_with(enumerable1, enumerable2, fun) do
    self = self()
    Enum.zip_with(
      enumerable1,
      enumerable2,
      &(spawn_link(fn -> send(self, {self(), :parallel_zip_with_3, fun.(&1, &2)}) end))
    )
    |> Enum.map(&(receive do: ({^&1, :parallel_zip_with_3, result} -> result)))
  end
end

defmodule Meal.Delegate do
  defmacro __using__(to: module, only: :functions) when is_atom(module) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module = Atom.to_string(unquote(module))
                         |> String.starts_with?("Elixir")
      arg = if is_elixir_module do
        functions = unquote(module).__info__(:functions)
                    |> Enum.filter(
                         fn {name, arity} ->
                           !Macro.operator?(name, arity)
                           && {name, arity} != {:__struct__, 0}
                           && {name, arity} != {:__struct__, 1}
                         end
                       )
        [functions: functions, to: unquote(module)]
      else
        functions = unquote(module).module_info(:exports)
                    |> Enum.filter(
                         fn {name, arity} ->
                           {name, arity} != {:module_info, 0}
                           && {name, arity} != {:module_info, 1}
                         end
                       )
        [functions: functions, to: ":" <> Atom.to_string(unquote(module))]
      end

      unquote(delegate_functions(quote(do: arg)))
    end
  end

  defmacro __using__(to: module, only: :macros) when is_atom(module) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module = Atom.to_string(unquote(module))
                         |> String.starts_with?("Elixir")

      if is_elixir_module do
        macros = unquote(module).__info__(:macros)
                 |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))
        arg = [macros: macros, to: unquote(module)]
        unquote(delegate_macros(quote(do: arg)))
      else
        raise "can not delegate macros to erlang module"
      end
    end
  end

  defmacro __using__(to: module, only: list) when is_atom(module) and is_list(list) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module = Atom.to_string(unquote(module))
                         |> String.starts_with?("Elixir")

      if is_elixir_module do
        functions = unquote(module).__info__(:functions)
                    |> Enum.filter(
                         fn {name, arity} ->
                           !Macro.operator?(name, arity)
                           && {name, arity} != {:__struct__, 0}
                           && {name, arity} != {:__struct__, 1}
                         end
                       )
        macros = unquote(module).__info__(:macros)
                 |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))

        %{functions: functions, macros: macros} = Enum.reduce(
          unquote(list),
          %{functions: [], macros: []},
          fn info, acc ->
            cond do
              info in functions ->
                update_in(acc, [Access.key(:functions)], fn functions -> [info | functions] end)
              info in macros ->
                update_in(acc, [Access.key(:macros)], fn macros -> [info | macros] end)
              {name, arity} = info ->
                raise "cannot delegate to #{unquote(module)}.#{name}/#{arity} because it is undefined or private"
            end
          end
        )

        arg = [functions: functions, to: unquote(module)]
        unquote(delegate_functions(quote(do: arg)))
        arg = [macros: macros, to: unquote(module)]
        unquote(delegate_macros(quote(do: arg)))
      else
        functions = unquote(module).module_info(:exports)
                    |> Enum.filter(
                         fn {name, arity} ->
                           {name, arity} != {:module_info, 0}
                           && {name, arity} != {:module_info, 1}
                         end
                       )

        %{functions: functions} = Enum.reduce(
          unquote(list),
          %{functions: []},
          fn info, acc ->
            cond do
              info in functions ->
                update_in(acc, [Access.key(:functions)], fn functions -> [info | functions] end)
              {name, arity} = info ->
                raise "cannot delegate to #{unquote(module)}.#{name}/#{arity} because it is undefined or private"
            end
          end
        )

        arg = [functions: functions, to: ":" <> Atom.to_string(unquote(module))]
        unquote(delegate_functions(quote(do: arg)))
      end
    end
  end

  defmacro __using__(to: module, except: list) when is_atom(module) and is_list(list) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module = Atom.to_string(unquote(module))
                         |> String.starts_with?("Elixir")

      if is_elixir_module do
        functions = unquote(module).__info__(:functions)
                    |> Enum.filter(
                         fn {name, arity} ->
                           !Macro.operator?(name, arity)
                           && {name, arity} != {:__struct__, 0}
                           && {name, arity} != {:__struct__, 1}
                         end
                       )
        macros = unquote(module).__info__(:macros)
                 |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))

        functions = Keyword.filter(functions, fn info -> info not in unquote(list) end)
        macros = Keyword.filter(macros, fn info -> info not in unquote(list) end)

        arg = [functions: functions, to: unquote(module)]
        unquote(delegate_functions(quote(do: arg)))
        arg = [macros: macros, to: unquote(module)]
        unquote(delegate_macros(quote(do: arg)))
      else
        functions = unquote(module).module_info(:exports)
                    |> Enum.filter(
                         fn {name, arity} ->
                           {name, arity} != {:module_info, 0}
                           && {name, arity} != {:module_info, 1}
                         end
                       )

        functions = Keyword.filter(functions, fn info -> info not in unquote(list) end)

        arg = [functions: functions, to: ":" <> Atom.to_string(unquote(module))]
        unquote(delegate_functions(quote(do: arg)))
      end
    end
  end

  defmacro __using__(to: module) when is_atom(module) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module = Atom.to_string(unquote(module))
                         |> String.starts_with?("Elixir")

      Meal.Delegate.__using__(to: unquote(module), only: :functions)

      if is_elixir_module do
        Meal.Delegate.__using__(to: unquote(module), only: :macros)
      end
    end
  end

  defp delegate_functions(arg) do
    quote bind_quoted: [
            arg: arg
          ] do
      [functions: functions, to: module] = arg
      get_delegate_function_str = fn {name, arity}, module ->
        """
        defdelegate #{name}(#{Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1)))}), to: #{module}
        """
      end

      for {name, arity} <- functions do
        Code.eval_string(get_delegate_function_str.({name, arity}, module), [], __ENV__)
      end
    end
  end

  defp delegate_macros(arg) do
    quote bind_quoted: [
            arg: arg
          ] do
      [macros: macros, to: module] = arg
      get_delegate_macro_str = fn {name, arity}, module ->
        args_str = Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1)))
        unquote_args_str = Enum.map_join(1..arity//1, ",", &("unquote(" <> "arg" <> to_string(&1) <> ")"))
        """
            defmacro #{name}(#{args_str}) do
              quote do
                require #{module}
                #{module}.#{name}(#{unquote_args_str})
              end
            end
        """
      end

      for {name, arity} <- macros do
        Code.eval_string(get_delegate_macro_str.({name, arity}, module), [], __ENV__)
      end
    end
  end
end