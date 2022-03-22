defmodule Meal.ExecuteServer do
  @pid_name :execute_server
  @on_load :start_execute_server
  defp start_execute_server do
    Process.register(
      spawn(fn ->
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
      end),
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

    Kernel.send(@pid_name, {code_, Keyword.merge(binding, self_pid__: self())})

    receive do
      {Meal.ExecuteServer.ExecuteResult, result} -> result
    end
  end

  def send(code: code, binding: binding, async: false) do
    code_ =
      quote do
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
