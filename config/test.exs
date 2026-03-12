import Config

config :logger, level: :warning

config :phoenix,
  plug_init_mode: :runtime

config :ex_unit,
  assert_receive_timeout: 1_000
