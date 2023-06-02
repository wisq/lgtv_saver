import Config

config :lgtv_saver,
  tv_ip: "192.168.2.165",
  wake_mac: "20:17:42:ba:92:0f",
  wake_broadcast: "192.168.2.255",
  saver_input: "HDMI_4",
  bindings: %{
    "HDMI_1" => %{
      idle_time: 30,
      port: 3232
    }
  }

config :logger, level: :debug
