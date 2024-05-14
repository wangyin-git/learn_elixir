defmodule Meal.Delegate do
  defmacro __using__(to: module, only: :functions) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module =
        Atom.to_string(unquote(module))
        |> String.starts_with?("Elixir")

      arg =
        if is_elixir_module do
          functions =
            unquote(module).__info__(:functions)
            |> Enum.filter(fn {name, arity} ->
              !Macro.operator?(name, arity) &&
                {name, arity} != {:__struct__, 0} &&
                {name, arity} != {:__struct__, 1}
            end)

          [functions: functions, to: unquote(module)]
        else
          functions =
            unquote(module).module_info(:exports)
            |> Enum.filter(fn {name, arity} ->
              {name, arity} != {:module_info, 0} &&
                {name, arity} != {:module_info, 1}
            end)

          [functions: functions, to: ":" <> Atom.to_string(unquote(module))]
        end

      unquote(delegate_functions(quote(do: arg)))
    end
  end

  defmacro __using__(to: module, only: :macros) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module =
        Atom.to_string(unquote(module))
        |> String.starts_with?("Elixir")

      if is_elixir_module do
        macros =
          unquote(module).__info__(:macros)
          |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))

        arg = [macros: macros, to: unquote(module)]
        unquote(delegate_macros(quote(do: arg)))
      else
        raise "can not delegate macros to erlang module"
      end
    end
  end

  defmacro __using__(to: module, only: list) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module =
        Atom.to_string(unquote(module))
        |> String.starts_with?("Elixir")

      if is_elixir_module do
        functions =
          unquote(module).__info__(:functions)
          |> Enum.filter(fn {name, arity} ->
            !Macro.operator?(name, arity) &&
              {name, arity} != {:__struct__, 0} &&
              {name, arity} != {:__struct__, 1}
          end)

        macros =
          unquote(module).__info__(:macros)
          |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))

        %{functions: functions, macros: macros} =
          Enum.reduce(
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
        functions =
          unquote(module).module_info(:exports)
          |> Enum.filter(fn {name, arity} ->
            {name, arity} != {:module_info, 0} &&
              {name, arity} != {:module_info, 1}
          end)

        %{functions: functions} =
          Enum.reduce(
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

  defmacro __using__(to: module, except: list) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module =
        Atom.to_string(unquote(module))
        |> String.starts_with?("Elixir")

      if is_elixir_module do
        functions =
          unquote(module).__info__(:functions)
          |> Enum.filter(fn {name, arity} ->
            !Macro.operator?(name, arity) &&
              {name, arity} != {:__struct__, 0} &&
              {name, arity} != {:__struct__, 1}
          end)

        macros =
          unquote(module).__info__(:macros)
          |> Enum.filter(&(!Macro.operator?(elem(&1, 0), elem(&1, 1))))

        functions = Keyword.filter(functions, fn info -> info not in unquote(list) end)
        macros = Keyword.filter(macros, fn info -> info not in unquote(list) end)

        arg = [functions: functions, to: unquote(module)]
        unquote(delegate_functions(quote(do: arg)))
        arg = [macros: macros, to: unquote(module)]
        unquote(delegate_macros(quote(do: arg)))
      else
        functions =
          unquote(module).module_info(:exports)
          |> Enum.filter(fn {name, arity} ->
            {name, arity} != {:module_info, 0} &&
              {name, arity} != {:module_info, 1}
          end)

        functions = Keyword.filter(functions, fn info -> info not in unquote(list) end)

        arg = [functions: functions, to: ":" <> Atom.to_string(unquote(module))]
        unquote(delegate_functions(quote(do: arg)))
      end
    end
  end

  defmacro __using__(to: module) do
    quote do
      if !Code.ensure_loaded?(unquote(module)) do
        raise "can not find module #{unquote(module)}"
      end

      is_elixir_module =
        Atom.to_string(unquote(module))
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

      defoverridable functions
    end
  end

  defp delegate_macros(arg) do
    quote bind_quoted: [
            arg: arg
          ] do
      [macros: macros, to: module] = arg

      get_delegate_macro_str = fn {name, arity}, module ->
        args_str = Enum.map_join(1..arity//1, ",", &("arg" <> to_string(&1)))

        unquote_args_str =
          Enum.map_join(1..arity//1, ",", &("unquote(" <> "arg" <> to_string(&1) <> ")"))

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

      defoverridable macros
    end
  end
end
