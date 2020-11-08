defmodule LgtvSaver.Waker do
  require Logger
  alias __MODULE__

  @enforce_keys [:broadcast, :mac]
  defstruct(
    broadcast: nil,
    mac: nil
  )

  def new(broadcast, mac) do
    %Waker{broadcast: broadcast, mac: mac}
  end

  def wake(%Waker{broadcast: broadcast, mac: mac}) do
    WOL.send(mac, broadcast_addr: broadcast)
  end
end
