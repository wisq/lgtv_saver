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
    DateTime.utc_now() |> DateTime.to_unix()
  end

  @impl true
  def init({tv, input, options}) do
    idle_time = Map.get(options, :idle_time, @default_idle_time)
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
      {secs, ""} ->
        Logger.debug("#{state.input}: Idle for #{secs} seconds")
        {:noreply, %State{state | last_active: current_time() - secs}, {:continue, :activity}}

      _ ->
        Logger.debug("#{state.input}: Unexpected data: #{inspect(data)}")
        {:noreply, state, {:continue, :activity}}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.debug("#{state.input}: Activity timeout")
    TV.inactive(state.tv, state.input)
    {:noreply, state, state.idle_time * 1000}
  end

  @impl true
  def handle_continue(:activity, state) do
    secs = state.last_active + state.idle_time - current_time()

    if secs > 0 do
      Logger.debug("#{state.input}: Activity timeout in #{inspect(secs)} seconds")
      TV.active(state.tv, state.input)
      {:noreply, state, Kernel.max(0, secs * 1000)}
    else
      Logger.debug("#{state.input}: Activity timeout #{inspect(0 - secs)} seconds ago")
      TV.inactive(state.tv, state.input)
      {:noreply, state, state.idle_time * 1000}
    end
  end
end
