import Config

config :lgtv_saver,
  tv_ip: "192.168.2.118",
  saver_input: "HDMI_4",
  bindings: %{
    "HDMI_1" => %{
      idle_time: 300,
      port: 3232
    }
  }

config :logger, :console,
  level: :info,
  format: "$metadata[$level] $levelpad$message\n"
