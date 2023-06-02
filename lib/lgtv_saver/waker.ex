defmodule LgtvSaver.Waker do
  require Logger
  alias __MODULE__

  @default_port 9

  @enforce_keys [:broadcast, :mac]
  defstruct(
    broadcast: nil,
    mac: nil,
    port: @default_port
  )

  def new(broadcast, mac) do
    %Waker{broadcast: broadcast, mac: mac}
  end

  def none, do: :no_waker

  def wake(%Waker{broadcast: broadcast, mac: mac, port: port}) do
    WOL.send(mac, broadcast_addr: broadcast, port: port)
  end

  def wake(:no_waker), do: :noop
end
