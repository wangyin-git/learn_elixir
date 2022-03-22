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
    code =
      quote do
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
      head =
        Iterator.next(iter)
        |> elem(1)

      reduce(iter, fun.(head, acc), fun)
    end
  end
end
