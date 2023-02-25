import Config

config :logger, :console,
  format: "$time [$level] $message $metadata\n",
  metadata: [:socket]
