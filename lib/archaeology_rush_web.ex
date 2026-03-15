defmodule ArchaeologyRushWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :archaeology_rush

  @session_options [
    store: :cookie,
    key: "_archaeology_rush_key",
    signing_salt: "demo-salt"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Session, @session_options

  plug ArchaeologyRushWeb.Router
end

defmodule ArchaeologyRushWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ArchaeologyRushWeb do
    pipe_through :browser

    get "/favicon.ico", AssetFallbackController, :icon
    get "/apple-touch-icon.png", AssetFallbackController, :icon
    get "/apple-touch-icon-precomposed.png", AssetFallbackController, :icon
    live "/", DemoLive
  end
end

defmodule ArchaeologyRushWeb.AssetFallbackController do
  use Phoenix.Controller, formats: [:html]

  def icon(conn, _params) do
    send_resp(conn, 204, "")
  end
end

defmodule ArchaeologyRushWeb.DemoLive do
  use Phoenix.LiveView

  alias ArchaeologyRush.Demo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :demo_output, Demo.run())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main style="max-width: 960px; margin: 0 auto; padding: 32px 20px 80px; font-family: Georgia, serif;">
      <h1 style="font-size: 2rem; margin-bottom: 16px;">ArchaeologyRush Live Demo</h1>
      <p style="margin-bottom: 20px; line-height: 1.6;">
        `Excavation` と `game_status/1` の現在のデモ出力をそのまま LiveView 画面に載せています。
      </p>
      <pre style="background: #f4efe4; border: 1px solid #c9b79c; padding: 20px; overflow-x: auto; line-height: 1.5;"><%= @demo_output %></pre>
    </main>
    """
  end
end

defmodule ArchaeologyRushWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", _assigns), do: "Not Found"
  def render("500.html", _assigns), do: "Internal Server Error"
  def render(_template, _assigns), do: "Unexpected Error"
end
