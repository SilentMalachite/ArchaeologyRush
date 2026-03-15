defmodule ArchaeologyRush.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = repo_children() ++ web_children()

    opts = [strategy: :one_for_one, name: ArchaeologyRush.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repo_children do
    if Application.get_env(:archaeology_rush, :start_repo, true) do
      [
        ArchaeologyRush.Repo
      ]
    else
      []
    end
  end

  defp web_children do
    if Application.get_env(:archaeology_rush, :start_web, true) do
      [
        {Phoenix.PubSub, name: ArchaeologyRush.PubSub},
        ArchaeologyRushWeb.Endpoint
      ]
    else
      []
    end
  end
end
