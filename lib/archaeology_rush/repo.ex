defmodule ArchaeologyRush.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :archaeology_rush,
    adapter: Ecto.Adapters.SQLite3
end
