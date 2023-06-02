defmodule LSTest.WakeServer do
  use GenServer, restart: :temporary

  alias LgtvSaver.Waker

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def get_waker(pid) do
    {port, mac} = GenServer.call(pid, :get_port_and_mac)
    %Waker{broadcast: "127.0.0.1", mac: mac, port: port}
  end

  def next_message(pid, timeout \\ 200) do
    try do
      GenServer.call(pid, :next_message, timeout)
    catch
      :exit, {:timeout, _} -> :timeout
    end
  end

  defmodule State do
    @enforce_keys [:socket]
    defstruct(
      socket: nil,
      messages: :queue.new(),
      waiting: nil,
      mac: nil
    )
  end

  @impl true
  def init(_) do
    {:ok, socket} = :gen_udp.open(0, [:binary, {:active, true}])
    {:ok, %State{socket: socket, mac: generate_mac()}}
  end

  @impl true
  def handle_call(:get_port_and_mac, _from, state) do
    {:ok, port} = :inet.port(state.socket)
    mac = state.mac |> mac_to_hex()
    {:reply, {port, mac}, state}
  end

  @impl true
  def handle_call(:next_message, from, %State{waiting: nil} = state) do
    case :queue.out(state.messages) do
      {{:value, msg}, new_msgs} -> {:reply, msg, %State{state | messages: new_msgs}}
      {:empty, _} -> {:noreply, %State{state | waiting: from}}
    end
  end

  @impl true
  def handle_info({:udp, _, _, _, data}, state) do
    msg = parse_wol(data, state.mac)

    case state.waiting do
      nil ->
        {:noreply, %State{state | messages: :queue.in(msg, state.messages)}}

      from ->
        GenServer.reply(from, msg)
        {:noreply, %State{state | waiting: nil}}
    end
  end

  defp generate_mac, do: 1..6 |> Enum.map(fn _ -> Enum.random(1..255) end)

  defp mac_to_hex(mac) do
    mac
    |> Enum.map(fn n ->
      Integer.to_string(n, 16)
      |> String.pad_leading(2, "0")
    end)
    |> Enum.join(":")
  end

  defp parse_wol(wol, expect_mac) do
    with [bcast | macs] <- wol |> :binary.bin_to_list() |> Enum.chunk_every(6),
         [255, 255, 255, 255, 255, 255] <- bcast,
         [^expect_mac] <- macs |> Enum.uniq() do
      :valid
    else
      _ -> :invalid
    end
  end
end
