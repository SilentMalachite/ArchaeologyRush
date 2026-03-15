import Config

config :archaeology_rush,
  ecto_repos: [ArchaeologyRush.Repo]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :esbuild, :version, "0.25.0"

config :tailwind, :version, "4.1.12"

import_config "#{config_env()}.exs"
