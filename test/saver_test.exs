defmodule LgtvSaver.SaverTest do
  use ExUnit.Case, async: true

  alias LSTest.{MockGenServer, WakeServer}
  alias LgtvSaver.Saver

  describe "without waker" do
    setup :start_saver

    test "switches to saver input when current input becomes inactive", %{saver: saver, tv: tv} do
      Saver.input_changed(saver, nil, "HDMI_1")
      Saver.inactive(saver, "HDMI_1")
      assert MockGenServer.next_cast(tv) == {:select_input, "HDMI_4"}
    end

    test "does not switch to saver if a different input goes inactive", %{saver: saver, tv: tv} do
      Saver.input_changed(saver, nil, "HDMI_1")
      Saver.inactive(saver, "HDMI_2")
      assert MockGenServer.next_cast(tv) == :timeout
    end

    test "switches back to input when it becomes active again", %{saver: saver, tv: tv} do
      Saver.input_changed(saver, "HDMI_1", "HDMI_4")
      Saver.active(saver, "HDMI_1")
      assert MockGenServer.next_cast(tv) == {:select_input, "HDMI_1"}
    end

    test "does not switch back to input if it was not the previous input", %{saver: saver, tv: tv} do
      Saver.input_changed(saver, "HDMI_1", "HDMI_4")
      Saver.active(saver, "HDMI_2")
      assert MockGenServer.next_cast(tv) == :timeout
    end

    test "repeats input change if TV powers on into saver input", %{saver: saver, tv: tv} do
      Saver.input_changed(saver, "HDMI_1", "HDMI_4")

      Saver.active(saver, "HDMI_1")
      assert MockGenServer.next_cast(tv) == {:select_input, "HDMI_1"}

      # Power on into saver:
      Saver.input_changed(saver, nil, "HDMI_4")
      assert MockGenServer.next_cast(tv) == {:select_input, "HDMI_1"}

      # Power on again, still haven't acknowledged input change:
      Saver.input_changed(saver, nil, "HDMI_4")
      assert MockGenServer.next_cast(tv) == {:select_input, "HDMI_1"}

      # Now we acknowledge the change, so it shouldn't happen again:
      Saver.input_changed(saver, "HDMI_4", "HDMI_1")
      Saver.input_changed(saver, nil, "HDMI_4")
      assert MockGenServer.next_cast(tv) == :timeout
    end
  end

  describe "with waker" do
    setup [:with_waker, :start_saver]

    test "sends WOL to TV when changing to active input", %{saver: saver, wake: wake} do
      Saver.input_changed(saver, "HDMI_1", "HDMI_4")
      Saver.active(saver, "HDMI_1")
      assert WakeServer.next_message(wake) == :valid
    end

    test "does not send WOL to TV when not changing input", %{saver: saver, wake: wake} do
      Saver.input_changed(saver, "HDMI_1", "HDMI_4")
      Saver.active(saver, "HDMI_2")
      assert WakeServer.next_message(wake) == :timeout
    end
  end

  defp with_waker(_ctx) do
    {:ok, wake_server} = start_supervised(WakeServer)
    [wake: wake_server, waker_option: WakeServer.get_waker(wake_server)]
  end

  defp start_saver(ctx) do
    {:ok, tv} = start_supervised(MockGenServer)

    {:ok, saver} =
      start_supervised(%{
        id: :saver,
        start:
          {LgtvSaver.Saver, :start_link,
           [
             tv,
             Map.get(ctx, :saver_input, "HDMI_4"),
             Map.get(ctx, :waker_option, :no_waker),
             [name: nil]
           ]}
      })

    [saver: saver, tv: tv]
  end
end
