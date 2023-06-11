defmodule LgtvSaver.Watcher do
  use GenServer
  require Logger
  alias LgtvSaver.Saver

  @default_idle_time 300
  @bind_any {0, 0, 0, 0}

  defmodule State do
    @enforce_keys [:socket, :saver, :input, :idle_time, :start_time]
    defstruct(
      socket: nil,
      ds4_socket: nil,
      saver: nil,
      input: nil,
      idle_time: nil,
      start_time: nil,
      last_active: nil,
      last_ds4_active: nil
    )
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_ports(pid), do: GenServer.call(pid, :get_ports)

  defp current_time() do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end

  @impl true
  def init(opts) do
    saver = Keyword.fetch!(opts, :saver)
    input = Keyword.fetch!(opts, :input)
    port = Keyword.fetch!(opts, :port)

    idle_time = Keyword.get(opts, :idle_time, @default_idle_time) * 1000
    ip = Keyword.get(opts, :bind, @bind_any)

    {:ok, socket} = :gen_udp.open(port, [:binary, ip: ip, active: true])

    {:ok,
     %State{
       socket: socket,
       ds4_socket: open_ds4_socket(opts),
       saver: saver,
       input: input,
       idle_time: round(idle_time),
       start_time: current_time()
     }, {:continue, :activity}}
  end

  defp open_ds4_socket(opts) do
    case Keyword.fetch(opts, :ds4_port) do
      {:ok, port} ->
        {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
        socket

      :error ->
        nil
    end
  end

  @impl true
  def handle_call(:get_ports, _from, state) do
    reply = {port(state.socket), port(state.ds4_socket)}
    {:reply, reply, state, {:continue, :activity}}
  end

  defp port(nil), do: nil

  defp port(socket) do
    {:ok, port} = :inet.port(socket)
    port
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
  def handle_info({:udp, socket, _address, _port, data}, %State{ds4_socket: socket} = state) do
    case data do
      <<"/ds4windows/monitor/", _, "/plug\0", _::binary>> ->
        Logger.debug("#{state.input}: ignoring DS4 plug event")
        {:noreply, state, state.idle_time}

      "/ds4" <> _ ->
        Logger.debug("#{state.input}: DS4 gamepad activity")
        {:noreply, %State{state | last_ds4_active: current_time()}, state.idle_time}

      _ ->
        Logger.warn("#{state.input}: Non-DS4 packet received: #{inspect(data)}")
        {:noreply, state, state.idle_time}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.info("#{state.input}: Activity timeout.")
    Saver.inactive(state.saver, state.input)
    {:noreply, state, state.idle_time}
  end

  @impl true
  def handle_continue(:activity, state) do
    {is_active, ttl_ms} = calculate_ttl(state)

    if ttl_ms > 0 do
      Logger.debug("#{state.input}: Activity timeout in #{inspect(ttl_ms)} ms")
      if is_active, do: Saver.active(state.saver, state.input)
      {:noreply, state, ttl_ms}
    else
      Logger.debug("#{state.input}: Activity timeout #{inspect(0 - ttl_ms)} ms ago")
      Saver.inactive(state.saver, state.input)
      {:noreply, state, state.idle_time * 1000}
    end
  end

  defp calculate_ttl(%State{last_active: nil, last_ds4_active: nil} = state) do
    {false, state.start_time + state.idle_time - current_time()}
  end

  defp calculate_ttl(%State{last_ds4_active: nil} = state) do
    {true, state.last_active + state.idle_time - current_time()}
  end

  defp calculate_ttl(state) do
    {true, max(state.last_active, state.last_ds4_active) + state.idle_time - current_time()}
  end
end
