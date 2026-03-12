import Config

config :logger, :console,
  level: :debug

config :phoenix,
  stacktrace_depth: 20,
  plug_init_mode: :runtime
