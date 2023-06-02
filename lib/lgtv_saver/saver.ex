defmodule LgtvSaver.Saver do
  use GenServer
  require Logger
  alias LgtvSaver.{TV, Waker}

  defmodule State do
    @enforce_keys [:tv, :saver_input, :waker]
    defstruct(
      tv: nil,
      saver_input: nil,
      waker: nil,
      current_input: nil,
      previous_input: nil,
      wanted_input: nil
    )
  end

  def start_link(opts) do
    {tv, opts} = Keyword.pop!(opts, :tv)
    {input, opts} = Keyword.pop!(opts, :saver_input)
    {waker, opts} = Keyword.pop(opts, :waker, Waker.none())

    GenServer.start_link(__MODULE__, {tv, input, waker}, opts)
  end

  def input_changed(pid, from, to) do
    :ok = GenServer.cast(pid, {:input_changed, from, to})
  end

  def active(pid, input) do
    :ok = GenServer.cast(pid, {:active, input})
  end

  def inactive(pid, input) do
    :ok = GenServer.cast(pid, {:inactive, input})
  end

  @impl true
  def init({tv, input, waker}) do
    {:ok, %State{tv: tv, saver_input: input, waker: waker}}
  end

  defp check_wanted(%State{wanted_input: nil} = state), do: state

  defp check_wanted(%State{current_input: input, wanted_input: input} = state) do
    Logger.debug("Saver: Entered wanted state #{inspect(input)}.")
    %State{state | wanted_input: nil}
  end

  defp check_wanted(%State{wanted_input: wanted} = state) do
    Logger.debug("Saver: Still want state #{inspect(wanted)}.")
    state
  end

  @impl true
  def handle_cast({:input_changed, nil, saver}, %State{saver_input: saver} = state) do
    if state.wanted_input do
      Logger.info("Saver: Powered on into saver; trying #{inspect(state.wanted_input)} ...")
      TV.select_input(state.tv, state.wanted_input)
    end

    {:noreply, %State{state | current_input: saver} |> check_wanted()}
  end

  @impl true
  def handle_cast({:input_changed, from, saver}, %State{saver_input: saver} = state) do
    Logger.info("Saver: Entered saver from #{inspect(from)}.")
    {:noreply, %State{state | current_input: saver, previous_input: from} |> check_wanted()}
  end

  @impl true
  def handle_cast({:input_changed, nil, nil}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:input_changed, from, nil}, %State{saver_input: from} = state) do
    Logger.info("Saver: Powered off from saver input #{inspect(from)}.")
    {:noreply, %State{state | current_input: nil}}
  end

  @impl true
  def handle_cast({:input_changed, from, nil}, state) do
    Logger.info("Saver: Powered off from regular input #{inspect(from)}.")
    {:noreply, %State{state | current_input: nil, previous_input: from}}
  end

  @impl true
  def handle_cast({:input_changed, from, to}, state) do
    Logger.info("Saver: Input changed from #{inspect(from)} to #{inspect(to)}.")
    {:noreply, %State{state | current_input: to, previous_input: nil, wanted_input: nil}}
  end

  @impl true
  def handle_cast({:active, input}, state) do
    if state.previous_input == input do
      Logger.info("Saver: Previous input #{inspect(input)} has become active.")
      Waker.wake(state.waker)
      TV.select_input(state.tv, input)
      {:noreply, %State{state | wanted_input: input}}
    else
      Logger.debug("Saver: Input #{inspect(input)} is active.")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:inactive, input}, state) do
    if state.current_input == input do
      Logger.info("Saver: Current input #{inspect(input)} has become inactive.")
      TV.select_input(state.tv, state.saver_input)
    else
      Logger.debug("Input #{inspect(input)} is inactive.")
    end

    {:noreply, state}
  end
end
