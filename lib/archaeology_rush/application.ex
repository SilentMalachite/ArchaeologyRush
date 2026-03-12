defmodule ArchaeologyRush.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = repo_children()

    opts = [strategy: :one_for_one, name: ArchaeologyRush.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repo_children do
    if Application.get_env(:archaeology_rush, :start_repo, true) do
      [
        ArchaeologyRush.Repo,
        # Phoenix endpoint and desktop supervisors are added in later chunks.
      ]
    else
      []
    end
  end
end
