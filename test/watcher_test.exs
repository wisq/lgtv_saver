defmodule LgtvSaver.WatcherTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias LSTest.MockGenServer
  alias LgtvSaver.Watcher

  @localhost {127, 0, 0, 1}

  describe "with basic options" do
    setup [:with_basic_options, :start_watcher]

    test "sets inactive if no activity received within idle limit", %{saver: saver} do
      assert_in_delta time_to_inactive(saver), 500, 100
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
  end

  describe "with DS4 options" do
    setup [:with_ds4_options, :start_watcher]

    test "sets active on next idle update if DS4 has valid OSC activity", %{saver: saver} = ctx do
      send_ds4(ctx)
      assert MockGenServer.next_cast(saver) == :timeout
      send_idle(ctx, 99999)
      assert MockGenServer.next_cast(saver) == {:active, "HDMI_1"}
    end

    test "goes inactive when DS4 stops sending", %{saver: saver} = ctx do
      # Simulates constant activity (every 5 to 10ms)
      ds4_pid = looper(5..10, fn -> send_ds4(ctx) end)
      # Simulates an AHK pinger (but every 100ms to keep things fast):
      looper(100..100, fn -> send_idle(ctx, 99999) end)

      Process.sleep(500)
      loop_stop(ds4_pid)
      assert_in_delta time_to_inactive(saver), 500, 100
    end
  end

  defp looper(ms, fun) do
    fun.()
    spawn_link(fn -> loop_inner(ms, fun) end)
  end

  defp loop_inner(ms, fun) do
    timeout = Enum.random(ms)

    receive do
      :stop -> :ok
    after
      timeout ->
        fun.()
        loop_inner(ms, fun)
    end
  end

  defp loop_stop(pid), do: send(pid, :stop)

  defp send_idle(%{udp_socket: udp, watcher_port: port}, ms) do
    :ok = :gen_udp.send(udp, {@localhost, port}, "#{ms}")
  end

  defp send_ds4(%{udp_socket: udp, ds4_port: port}) do
    msg = OSC.Message.construct("/ds4windows/monitor/0/square", [1])
    :ok = :gen_udp.send(udp, {@localhost, port}, OSC.Message.to_packet(msg))
  end

  defp with_basic_options(_ctx) do
    [options: %{idle_time: 0.5}]
  end

  defp with_ds4_options(_ctx) do
    [options: %{ds4_port: 0, idle_time: 0.5}]
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

    {port, ds4_port} = Watcher.get_ports(watcher)
    {:ok, udp} = :gen_udp.open(0, [:binary])

    [watcher: watcher, saver: saver, watcher_port: port, ds4_port: ds4_port, udp_socket: udp]
  end

  defp time_to_inactive(saver, start_time \\ DateTime.utc_now()) do
    if DateTime.utc_now() |> DateTime.diff(start_time, :millisecond) > 5000, do: raise("timeout")

    case MockGenServer.next_cast(saver, 1000) do
      {:active, "HDMI_1"} -> time_to_inactive(saver, start_time)
      {:inactive, "HDMI_1"} -> DateTime.utc_now() |> DateTime.diff(start_time, :millisecond)
    end
  end
end
