defmodule LSTest.MockGenServer do
  use GenServer
  require Logger

  @default_timeout 200

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def next_message(pid, timeout \\ @default_timeout) do
    try do
      GenServer.call(pid, :next_message, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
    end
  end

  def next_call(pid, timeout \\ @default_timeout) do
    case next_message(pid, timeout) do
      {:call, msg} -> msg
      :timeout -> :timeout
      other -> raise "Got #{inspect(other)} when expecting call"
    end
  end

  def next_cast(pid, timeout \\ @default_timeout) do
    case next_message(pid, timeout) do
      {:cast, msg} -> msg
      :timeout -> :timeout
      other -> raise "Got #{inspect(other)} when expecting cast"
    end
  end

  def add_response(pid, fun) do
    GenServer.cast(pid, {:add_response, fun})
  end

  def flush_messages(pid) do
    GenServer.cast(pid, :flush_messages)
  end

  defmodule State do
    @enforce_keys [:init]
    defstruct(
      init: nil,
      messages: :queue.new(),
      waiting: nil,
      responses: []
    )
  end

  @impl true
  def init(nil) do
    {:ok, %State{init: true}}
  end

  @impl true
  def handle_cast({:add_response, fun}, state) do
    {:noreply, %State{state | responses: [fun | state.responses]}}
  end

  @impl true
  def handle_cast(:flush_messages, state) do
    {:noreply, %State{state | messages: :queue.new()}}
  end

  @impl true
  def handle_cast(msg, state) do
    {:noreply, reply_or_record({:cast, msg}, state)}
  end

  @impl true
  def handle_call(:next_message, from, state) do
    case :queue.out(state.messages) do
      {{:value, msg}, messages} ->
        {:reply, msg, %State{state | messages: messages}}

      {:empty, _} ->
        {:noreply, %State{state | waiting: from}}
    end
  end

  @impl true
  def handle_call(msg, _from, state) do
    state = reply_or_record({:call, msg}, state)

    case state.responses |> first_matching_response(msg) do
      {:reply, msg} ->
        {:reply, msg, state}

      :no_match ->
        Logger.error("No matching response: #{inspect(msg)}")
        {:noreply, state}
    end
  end

  defp reply_or_record(msg, state) do
    case state.waiting do
      nil ->
        %State{state | messages: :queue.in(msg, state.messages)}

      from ->
        GenServer.reply(from, msg)
        %State{state | waiting: nil}
    end
  end

  defp first_matching_response(responses, msg) do
    responses
    |> Enum.reduce_while(:no_match, fn fun, acc ->
      try do
        {:halt, fun.(msg)}
      rescue
        MatchError -> {:cont, acc}
      end
    end)
  end
end
