defmodule LgtvSaver.Tv do
  use GenServer
  require Logger

  defmodule State do
    @enforce_keys [:client, :saver_input]
    defstruct(
      client: nil,
      saver_input: nil,
      inputs: %{},
      current_input: nil,
      previous_input: nil
    )
  end

  def start_link(ip, input) do
    GenServer.start_link(__MODULE__, {ip, input})
  end

  def active(pid, input) do
    :ok = GenServer.call(pid, {:active, input})
  end

  def inactive(pid, input) do
    :ok = GenServer.call(pid, {:inactive, input})
  end

  @impl true
  def init({ip, input}) do
    {:ok, pid} = ExLgtv.Client.start_link(ip)
    Process.send_after(self(), :setup, 1000)
    {:ok, %State{client: pid, saver_input: input}}
  end

  @impl true
  def handle_call({:active, input}, _from, state) do
    if state.previous_input == input do
      Logger.info("Previous input #{inspect(input)} has become active.")
      ExLgtv.Remote.Inputs.select(state.client, input)
    else
      Logger.debug("Input #{inspect(input)} is active.")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:inactive, input}, _from, state) do
    if state.current_input == input do
      Logger.info("Current input #{inspect(input)} has become inactive.")
      ExLgtv.Remote.Inputs.select(state.client, state.saver_input)
    else
      Logger.debug("Input #{inspect(input)} is inactive.")
    end

    {:reply, :ok, state}
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
    old = state.current_input
    new = id

    if state.saver_input == new do
      Logger.info("Screen saved -- changed from #{inspect(old)} to #{inspect(new)}.")
      %State{state | current_input: new, previous_input: old}
    else
      Logger.info("Changed to input #{inspect(id)}.")
      %State{state | current_input: id, previous_input: nil}
    end
  end
end
