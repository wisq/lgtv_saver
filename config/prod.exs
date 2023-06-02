import Config

config :lgtv_saver,
  tv_ip: "192.168.2.118",
  wake_mac: "58:fd:b1:7a:4b:b8",
  wake_broadcast: "192.168.2.255",
  saver_input: "HDMI_4",
  bindings: %{
    "HDMI_1" => %{
      idle_time: 300,
      port: 3232
    }
  }
