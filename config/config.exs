import Config

config :logger, :console,
  level: :info,
  format: "[$level] $message\n"

import_config "#{Mix.env()}.exs"
