defmodule Meal.Channel do
  @enforce_keys [:gen_server, :buff_size, :type]
  defstruct [:gen_server, :buff_size, :type]

  require Meal

  def new(buff_size \\ 0, type \\ :read_write)
      when Meal.is_non_neg_integer(buff_size) and type in [:read_write, :read_only, :write_only] do
    {:ok, gen_server} =
      DynamicSupervisor.start_child(Meal.Channel.Supervisor, {Meal.Channel.Server, buff_size})

    %__MODULE__{gen_server: gen_server, buff_size: buff_size, type: type}
  end

  def delay(milliseconds) do
    channel = new(0, :read_only)

    spawn(fn ->
      Process.sleep(milliseconds)

      try do
        GenServer.call(channel.gen_server, {:write, 0}, :infinity)
        close(channel)
      catch
        :exit, _ -> nil
      end
    end)

    channel
  end

  def read(channel, opts \\ [timeout: :infinity])

  def read(%__MODULE__{gen_server: gen_server, type: :read_only}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_read_call__(gen_server, timeout)
  end

  def read(%__MODULE__{gen_server: gen_server, type: :read_write}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_read_call__(gen_server, timeout)
  end

  defp __gen_server_read_call__(gen_server, timeout) do
    try do
      GenServer.call(gen_server, :read, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> :closed
    end
  end

  def write(channel, data, opts \\ [timeout: :infinity])

  def write(%__MODULE__{gen_server: gen_server, type: :write_only}, data, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_write_call__(gen_server, data, timeout)
  end

  def write(%__MODULE__{gen_server: gen_server, type: :read_write}, data, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_write_call__(gen_server, data, timeout)
  end

  defp __gen_server_write_call__(gen_server, data, timeout) do
    try do
      GenServer.call(gen_server, {:write, data}, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> :closed
    end
  end

  def peek(channel, opts \\ [timeout: :infinity])

  def peek(%__MODULE__{gen_server: gen_server, type: :read_only}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_peek_call__(gen_server, timeout)
  end

  def peek(%__MODULE__{gen_server: gen_server, type: :read_write}, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    __gen_server_peek_call__(gen_server, timeout)
  end

  defp __gen_server_peek_call__(gen_server, timeout) do
    try do
      GenServer.call(gen_server, :peek, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> :closed
    end
  end

  def close(%__MODULE__{gen_server: gen_server}, opts \\ [timeout: :infinity]) do
    timeout = Keyword.fetch!(opts, :timeout)

    try do
      GenServer.stop(gen_server, {:shutdown, :closed}, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> :ok
    end
  end

  defmacro read_op(channel) do
    quote do
      {unquote(channel), :read}
    end
  end

  defmacro peek_op(channel) do
    quote do
      {unquote(channel), :peek}
    end
  end

  defmacro write_op(channel, data) do
    quote do
      {{unquote(channel), unquote(data)}, :write}
    end
  end

  def select(channel_ops, opts \\ [timeout: :infinity]) do
    timeout = Keyword.fetch!(opts, :timeout)

    Meal.Parallel.find_value(
      channel_ops,
      :timeout,
      fn
        read_op(channel) ->
          {read_op(channel), Meal.Channel.read(channel)}

        peek_op(channel) ->
          {peek_op(channel), Meal.Channel.peek(channel)}

        write_op(channel, data) ->
          {write_op(channel, data), Meal.Channel.write(channel, data)}
      end,
      ordered: false,
      max_concurrency: Enum.count(channel_ops),
      timeout: timeout
    )
  end
end

defimpl Enumerable, for: Meal.Channel do
  def count(%Meal.Channel{}) do
    {:error, __MODULE__}
  end

  def member?(%Meal.Channel{}, _element) do
    {:error, __MODULE__}
  end

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(channel, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(channel, &1, fun)}

  def reduce(%Meal.Channel{} = channel, {:cont, acc}, fun) do
    case Meal.Channel.read(channel) do
      {:ok, element} -> reduce(channel, fun.(element, acc), fun)
      :closed -> {:done, acc}
    end
  end

  def slice(%Meal.Channel{}) do
    {:error, __MODULE__}
  end
end

defimpl Collectable, for: Meal.Channel do
  def into(%Meal.Channel{} = channel) do
    collector_fun = fn
      acc, {:cont, elem} ->
        case Meal.Channel.write(acc, elem) do
          :ok -> acc
          :closed -> raise "Write to closed Channel"
        end

      acc, :done ->
        acc

      _, :halt ->
        :ok
    end

    {channel, collector_fun}
  end
end
