defmodule LgtvSaver.TV do
  use GenServer
  require Logger

  defmodule State do
    @enforce_keys [:client, :saver_input]
    defstruct(
      ready: false,
      client: nil,
      saver_input: nil,
      inputs: %{},
      current_input: nil,
      previous_input: nil
    )
  end

  def start_link(ip, input, options \\ []) do
    GenServer.start_link(__MODULE__, {ip, input}, options)
  end

  def active(pid, input) do
    :ok = GenServer.cast(pid, {:active, input})
  end

  def inactive(pid, input) do
    :ok = GenServer.cast(pid, {:inactive, input})
  end

  @impl true
  def init({ip, input}) do
    {:ok, pid} = ExLgtv.Client.start_link(ip)
    Process.send_after(self(), :setup, 1000)
    {:ok, %State{client: pid, saver_input: input}}
  end

  @impl true
  def handle_cast(_any, %State{ready: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:active, input}, state) do
    if state.previous_input == input do
      Logger.info("Previous input #{inspect(input)} has become active.")
      ExLgtv.Remote.Inputs.select(state.client, input)
    else
      Logger.debug("Input #{inspect(input)} is active.")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:inactive, input}, state) do
    if state.current_input == input do
      Logger.info("Current input #{inspect(input)} has become inactive.")
      ExLgtv.Remote.Inputs.select(state.client, state.saver_input)
    else
      Logger.debug("Input #{inspect(input)} is inactive.")
    end

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
  def handle_info({"input_change", %{"appId" => ""}}, state) do
    Logger.info("TV appears to have turned off.")
    {:noreply, state}
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

    %State{state | inputs: input_map, ready: true}
  end

  defp handle_input_change(id, state) do
    old = state.current_input
    new = id

    cond do
      old == new ->
        Logger.debug("Input stayed the same: #{inspect(old)}")
        state

      state.saver_input == new ->
        Logger.info("Screen saved -- changed from #{inspect(old)} to #{inspect(new)}.")
        %State{state | current_input: new, previous_input: old}

      true ->
        Logger.info("Changed to input #{inspect(id)}.")
        %State{state | current_input: id, previous_input: nil}
    end
  end
end
