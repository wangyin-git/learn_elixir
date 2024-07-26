defmodule Meal.Channel.MailBox do
  defstruct queue: Meal.Queue.new(), current_size: 0, buff_size: 0
end

defmodule Meal.Channel.Reader do
  @enforce_keys [:from]
  defstruct [:from, type: :read]

  def alive?(%__MODULE__{from: from}) do
    Process.alive?(from |> elem(0))
  end
end

defmodule Meal.Channel.Writter do
  @enforce_keys [:from, :data]
  defstruct [:from, :data]

  def alive?(%__MODULE__{from: from}) do
    Process.alive?(from |> elem(0))
  end
end

defmodule Meal.Channel.State do
  defstruct mail_box: %Meal.Channel.MailBox{},
            readers: Meal.Queue.new(),
            writters: Meal.Queue.new()
end

defmodule Meal.Channel do
  use GenServer, restart: :temporary

  @enforce_keys [:gen_server, :buff_size]
  defstruct [:gen_server, :buff_size]

  require Meal
  alias Meal.Queue
  alias Meal.Channel.MailBox
  alias Meal.Channel.Reader
  alias Meal.Channel.Writter
  alias Meal.Channel.State

  def new(buff_size \\ 0) when Meal.is_non_neg_integer(buff_size) do
    {:ok, gen_server} =
      DynamicSupervisor.start_child(Meal.Channel.Supervisor, {__MODULE__, buff_size})

    %__MODULE__{gen_server: gen_server, buff_size: buff_size}
  end

  def start_link(buff_size) do
    GenServer.start_link(__MODULE__, %State{mail_box: %MailBox{buff_size: buff_size}})
  end

  def read(%__MODULE__{gen_server: gen_server}, opts \\ [timeout: :infinity]) do
    timeout = Keyword.fetch!(opts, :timeout)

    try do
      GenServer.call(gen_server, :read, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> :closed
    end
  end

  def write(%__MODULE__{gen_server: gen_server}, data, opts \\ [timeout: :infinity]) do
    timeout = Keyword.fetch!(opts, :timeout)

    try do
      GenServer.call(gen_server, {:write, data}, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
      :exit, _ -> raise "Write to closed Channel"
    end
  end

  def peek(%__MODULE__{gen_server: gen_server}, opts \\ [timeout: :infinity]) do
    timeout = Keyword.fetch!(opts, :timeout)

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

  defp __read__(%State{} = state) do
    mail_box = state.mail_box

    case Queue.deq(mail_box.queue) do
      {element, queue} ->
        mail_box = %MailBox{mail_box | queue: queue, current_size: mail_box.current_size - 1}
        {element, put_in(state.mail_box, mail_box)}

      :empty ->
        :empty
    end
  end

  defp __peek__(%State{} = state) do
    mail_box = state.mail_box

    case Queue.peek(mail_box.queue) do
      {:ok, element} ->
        {element, state}

      :empty ->
        :empty
    end
  end

  defp __write__(%State{} = state, data) do
    new_state = update_in(state.mail_box.queue, &Queue.enq(&1, data))
    new_state = update_in(new_state.mail_box.current_size, &(&1 + 1))
    new_state
  end

  @impl GenServer
  def init(init_state) do
    {:ok, init_state}
  end

  @impl GenServer
  def handle_call(:read, from, %State{} = state) do
    mail_box = state.mail_box

    cond do
      mail_box.current_size == 0 && mail_box.buff_size == 0 ->
        {:noreply, state, {:continue, {:have_reader, %Reader{from: from}}}}

      mail_box.current_size == 0 ->
        new_state = update_in(state.readers, &Queue.enq(&1, %Reader{from: from}))
        {:noreply, new_state}

      true ->
        {element, new_state} = __read__(state)
        {:reply, {:ok, element}, new_state, {:continue, :read_complete}}
    end
  end

  @impl GenServer
  def handle_call({:write, data}, from, %State{} = state) do
    current_size = state.mail_box.current_size
    buff_size = state.mail_box.buff_size

    cond do
      current_size == 0 && buff_size == 0 ->
        {:noreply, state, {:continue, {:have_writter, %Writter{from: from, data: data}}}}

      current_size < buff_size ->
        {:reply, :ok, __write__(state, data), {:continue, :write_complete}}

      true ->
        new_state = update_in(state.writters, &Queue.enq(&1, %Writter{from: from, data: data}))
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_call(:peek, from, %State{} = state) do
    mail_box = state.mail_box

    cond do
      mail_box.current_size == 0 && mail_box.buff_size == 0 ->
        {:noreply, state, {:continue, {:have_reader, %Reader{from: from, type: :peek}}}}

      mail_box.current_size == 0 ->
        new_state = update_in(state.readers, &Queue.enq(&1, %Reader{from: from, type: :peek}))
        {:noreply, new_state}

      true ->
        {element, new_state} = __peek__(state)
        {:reply, {:ok, element}, new_state}
    end
  end

  @impl GenServer
  def handle_continue(:read_complete, %State{} = state) do
    case Queue.deq(state.writters) do
      {writter, writters} ->
        new_state = %State{state | writters: writters}
        new_state = __write__(new_state, writter.data)
        GenServer.reply(writter.from, :ok)
        {:noreply, new_state, {:continue, :write_complete}}

      :empty ->
        new_state = %State{state | writters: Queue.new()}
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_continue(:write_complete, %State{} = state) do
    case Queue.deq(state.readers) do
      {reader, readers} ->
        new_state = %State{state | readers: readers}

        case reader.type do
          :read ->
            {element, new_state} = __read__(new_state)
            GenServer.reply(reader.from, {:ok, element})
            {:noreply, new_state, {:continue, :read_complete}}

          :peek ->
            {element, new_state} = __peek__(new_state)
            GenServer.reply(reader.from, {:ok, element})
            {:noreply, new_state, {:continue, :write_complete}}
        end

      :empty ->
        new_state = %State{state | readers: Queue.new()}
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_continue({:have_reader, %Reader{} = reader}, state) do
    case Queue.deq(state.writters) do
      {writter, writters} ->
        case reader.type do
          :read ->
            new_state = %State{state | writters: writters}
            GenServer.reply(reader.from, {:ok, writter.data})
            GenServer.reply(writter.from, :ok)
            {:noreply, new_state}

          :peek ->
            GenServer.reply(reader.from, {:ok, writter.data})
            {:noreply, state}
        end

      :empty ->
        new_state = %State{state | writters: Queue.new()}
        new_state = update_in(new_state.readers, &Queue.enq(&1, reader))
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_continue({:have_writter, %Writter{} = writter}, state) do
    case Queue.deq(state.readers) do
      {reader, readers} ->
        new_state = %State{state | readers: readers}

        case reader.type do
          :read ->
            GenServer.reply(reader.from, {:ok, writter.data})
            GenServer.reply(writter.from, :ok)
            {:noreply, new_state}

          :peek ->
            GenServer.reply(reader.from, {:ok, writter.data})
            {:noreply, new_state, {:continue, {:have_writter, writter}}}
        end

      :empty ->
        new_state = %State{state | readers: Queue.new()}
        new_state = update_in(new_state.writters, &Queue.enq(&1, writter))
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(_, state) do
    {:noreply, state}
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
