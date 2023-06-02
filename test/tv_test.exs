defmodule LgtvSaver.TVTest do
  use ExUnit.Case, async: true
  require Logger

  alias LSTest.MockGenServer

  @localhost_tuple {127, 0, 0, 1}
  @localhost_string "127.0.0.1"

  # This is a very minimal test, just to ensure that the `LgtvSaver.TV` module
  # can parse arguments and connect to an IP.
  #
  # Now that GenStage is a thing, I really need to rewrite ExLGTV to use it.
  # As such, there's not a ton of point in trying to make this an exhaustive
  # test suite at the moment.
  #
  # Also, apparently ExLGTV doesn't even take a port number, so this requires
  # that you not have anything listening on port 3000.

  test "connects to TV" do
    with {:ok, tcp} <- :gen_tcp.listen(3000, [:binary] ++ [ip: @localhost_tuple, active: false]) do
      {:ok, saver} = start_supervised(MockGenServer)

      {:ok, _tv} =
        start_supervised(%{
          id: :tv,
          start:
            {LgtvSaver.TV, :start_link,
             [
               saver,
               @localhost_string,
               []
             ]}
        })

      assert {:ok, conn} = :gen_tcp.accept(tcp, 1000)
      assert {:ok, "GET / HTTP/1.1\r\n" <> _} = :gen_tcp.recv(conn, 0)
    else
      {:error, :eaddrinuse} ->
        Logger.warning("Port 3000 in use, cannot run `LgtvSaver.TV` test")
    end
  end
end
