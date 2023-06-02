defmodule LgtvSaver.WatcherTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias LSTest.MockGenServer
  alias LgtvSaver.Watcher

  @localhost {127, 0, 0, 1}

  setup [:with_options, :start_watcher]

  test "sets inactive if no activity received", %{saver: saver} do
    assert MockGenServer.next_cast(saver, 1000) == {:inactive, "HDMI_1"}
  end

  test "sets active when activity received", %{saver: saver} = ctx do
    send_idle(ctx, 0)
    assert MockGenServer.next_cast(saver) == {:active, "HDMI_1"}
  end

  test "sets inactive if user goes idle", %{saver: saver} = ctx do
    send_idle(ctx, 1000)
    assert MockGenServer.next_cast(saver) == {:inactive, "HDMI_1"}
  end

  test "ignores negative idle times", %{saver: saver} = ctx do
    log =
      capture_log(fn ->
        send_idle(ctx, -99999)
        # No immediate response:
        assert MockGenServer.next_cast(saver, 200) == :timeout
      end)

    # Log includes malformed value:
    assert log =~ ~s{"-99999"}

    # Does eventually go idle as normal:
    assert MockGenServer.next_cast(saver, 1000) == {:inactive, "HDMI_1"}
  end

  defp send_idle(%{udp_socket: udp, watcher_port: port}, ms) do
    :ok = :gen_udp.send(udp, {@localhost, port}, "#{ms}")
  end

  defp with_options(_ctx) do
    [options: %{idle_time: 0.5}]
  end

  defp start_watcher(ctx) do
    {:ok, saver} = start_supervised(MockGenServer)

    options =
      Map.fetch!(ctx, :options)
      |> Map.merge(%{
        input: "HDMI_1",
        bind: @localhost,
        port: 0,
        saver: saver
      })
      |> Map.to_list()

    {:ok, watcher} = start_supervised({Watcher, options})

    port = Watcher.get_port(watcher)
    {:ok, udp} = :gen_udp.open(0, [:binary])

    [watcher: watcher, saver: saver, watcher_port: port, udp_socket: udp]
  end
end
