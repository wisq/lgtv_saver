defmodule LgtvSaver.Watcher do
  use GenServer
  require Logger
  alias LgtvSaver.TV

  @default_idle_time 300

  defmodule State do
    @enforce_keys [:socket, :tv, :input, :idle_time, :last_active]
    defstruct(
      socket: nil,
      tv: nil,
      input: nil,
      idle_time: nil,
      last_active: nil
    )
  end

  def start_link(tv, input, %{} = options) do
    GenServer.start_link(__MODULE__, {tv, input, options})
  end

  defp current_time() do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end

  @impl true
  def init({tv, input, options}) do
    idle_time = Map.get(options, :idle_time, @default_idle_time) * 1000
    ip = Map.get(options, :bind, {0, 0, 0, 0})
    port = Map.fetch!(options, :port)

    {:ok, socket} = :gen_udp.open(port, [:binary, ip: ip, active: true])

    {:ok,
     %State{
       socket: socket,
       tv: tv,
       input: input,
       idle_time: idle_time,
       last_active: current_time()
     }, {:continue, :activity}}
  end

  @impl true
  def handle_info({:udp, socket, _address, _port, data}, %State{socket: socket} = state) do
    case :string.chomp(data) |> Integer.parse() do
      {msecs, ""} when msecs >= 0 ->
        Logger.debug("#{state.input}: Idle for #{msecs} ms")
        {:noreply, %State{state | last_active: current_time() - msecs}, {:continue, :activity}}

      _ ->
        Logger.warn("#{state.input}: Unexpected data: #{inspect(data)}")
        {:noreply, state, {:continue, :activity}}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("#{state.input}: Activity timeout.")
    TV.inactive(state.tv, state.input)
    {:noreply, state, state.idle_time}
  end

  @impl true
  def handle_continue(:activity, state) do
    msecs = state.last_active + state.idle_time - current_time()

    cond do
      msecs > 1000 ->
        Logger.debug("#{state.input}: Activity timeout in #{inspect(msecs)} ms")
        TV.active(state.tv, state.input)
        {:noreply, state, msecs}

      msecs > 0 ->
        Logger.debug("#{state.input}: Activity timeout in less than a second")
        {:noreply, state, msecs}

      true ->
        Logger.debug("#{state.input}: Activity timeout #{inspect(0 - msecs)} ms ago")
        TV.inactive(state.tv, state.input)
        {:noreply, state, state.idle_time * 1000}
    end
  end
end
