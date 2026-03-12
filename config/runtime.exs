import Config

default_database_name =
  case config_env() do
    :test -> "archaeology_rush_test.sqlite3"
    _other -> "archaeology_rush.sqlite3"
  end

database_path =
  System.get_env("ARCHAEOLOGY_RUSH_DATABASE_PATH") ||
    Path.expand("../priv/repo/#{default_database_name}", __DIR__)

pool_size =
  case config_env() do
    :test -> 1
    _other -> String.to_integer(System.get_env("POOL_SIZE") || "5")
  end

config :archaeology_rush,
  start_repo: config_env() != :test

config :archaeology_rush, ArchaeologyRush.Repo,
  database: database_path,
  pool_size: pool_size,
  busy_timeout: 5_000,
  show_sensitive_data_on_connection_error: config_env() == :dev
