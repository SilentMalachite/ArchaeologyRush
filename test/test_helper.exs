{:ok, _} =
  Supervisor.start_link([{Phoenix.PubSub, name: ArchaeologyRush.PubSub}], strategy: :one_for_one)

{:ok, _} = ArchaeologyRushWeb.Endpoint.start_link()

ExUnit.start()
