defmodule LgtvSaver.TV do
  use GenServer
  require Logger
  alias LgtvSaver.Saver
  alias ExLgtv.Remote

  defmodule State do
    @enforce_keys [:saver, :client]
    defstruct(
      saver: nil,
      client: nil,
      ready: false,
      inputs: %{},
      current_input: nil
    )
  end

  def start_link(opts) do
    {saver, opts} = Keyword.pop!(opts, :saver)
    {ip, opts} = Keyword.pop!(opts, :ip)
    GenServer.start_link(__MODULE__, {saver, ip}, opts)
  end

  def select_input(pid, input) do
    :ok = GenServer.cast(pid, {:select_input, input})
  end

  @impl true
  def init({saver, ip}) do
    {:ok, pid} = ExLgtv.Client.start_link(ip)
    Process.send_after(self(), :setup, 1000)
    {:ok, %State{saver: saver, client: pid}}
  end

  @impl true
  def handle_cast(_any, %State{ready: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:select_input, input}, state) do
    if is_nil(state.current_input) do
      Logger.info("TV: Waking TV and changing to input #{inspect(input)}.")
      # Annoyingly, there doesn't seem to be a separate call for "turn on".
      # This effectively simulates pressing the power button.
      #
      # Sadly, I have to accept the risk that this might trigger
      # incorrectly and turn the TV off unexpectedly.  But it seems
      # to work fine so far.
      #
      # If the TV has actually powered off, this will just fail to send,
      # and nothing will happen.  Hopefully Waker will do its thing.
      Remote.turn_off(state.client)
    else
      Logger.info("TV: Changing to input #{inspect(input)}.")
    end

    Remote.Inputs.select(state.client, input)
    {:noreply, state}
  end

  @impl true
  def handle_info(:setup, state) do
    case ExLgtv.Remote.Inputs.list(state.client) do
      {:ok, inputs} ->
        {:noreply, %State{} = handle_setup(inputs, state)}

      {:error, _} ->
        Process.send_after(self(), :setup, 1000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({"input_change", _} = msg, %State{ready: false} = state) do
    # Received our first input_change event, so we're ready.
    handle_info(msg, %State{state | ready: true})
  end

  @impl true
  def handle_info({"input_change", %{"appId" => ""}}, state) do
    Logger.debug("TV appears to have turned off.")
    {:noreply, %State{} = handle_input_change(nil, state)}
  end

  @impl true
  def handle_info({"input_change", %{"appId" => app_id}}, state) do
    case Map.fetch(state.inputs, app_id) do
      {:ok, id} -> {:noreply, %State{} = handle_input_change(id, state)}
      :error -> {:noreply, state}
    end
  end

  defp handle_setup(%{"devices" => inputs}, state) do
    input_map =
      Map.new(inputs, fn
        %{"appId" => app, "id" => id} -> {app, id}
      end)

    {:ok, _} =
      ExLgtv.Client.subscribe(
        state.client,
        "input_change",
        "ssap://com.webos.applicationManager/getForegroundAppInfo",
        %{}
      )

    %State{state | inputs: input_map}
  end

  defp handle_input_change(id, state) do
    from = state.current_input
    to = id

    Logger.info("TV: Changed from #{inspect(from)} to #{inspect(to)}.")
    Saver.input_changed(state.saver, from, to)
    %State{state | current_input: to}
  end
end
