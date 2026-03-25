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
    live "/game", GameLive
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
    {:ok, assign(socket, :scenarios, Demo.scenarios())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main style="min-height: 100vh; background: linear-gradient(180deg, #f4f6fb 0%, #e9edf7 100%); padding: 40px 20px 72px; font-family: 'Noto Sans JP', 'Hiragino Sans', sans-serif; color: #24324a;">
      <section style="max-width: 1160px; margin: 0 auto;">
        <div style="background: #ffffff; border-radius: 28px; padding: 32px; box-shadow: 0 18px 40px rgba(36, 50, 74, 0.12); margin-bottom: 28px;">
          <div style="display: inline-flex; align-items: center; gap: 8px; background: #dde7ff; color: #2346a0; border-radius: 999px; padding: 8px 14px; font-size: 0.86rem; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase;">
            LiveView Demo
          </div>
          <h1 style="font-size: clamp(2rem, 5vw, 3.4rem); line-height: 1.05; margin: 18px 0 12px; font-weight: 800; letter-spacing: -0.03em;">
            ArchaeologyRush Scenario Board
          </h1>
          <p style="max-width: 760px; font-size: 1.02rem; line-height: 1.7; color: #55657f; margin: 0;">
            progression case / winning case / losing case をカードで整理し、`game_status/1` とターン推移をブラウザで見やすく確認できるようにしています。
          </p>
        </div>

        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 24px;">
          <article
            :for={scenario <- @scenarios}
            style="background: #ffffff; border-radius: 24px; overflow: hidden; box-shadow: 0 14px 32px rgba(36, 50, 74, 0.12);"
          >
            <div style={scenario_header_style(scenario.id)}>
              <div style="font-size: 0.78rem; letter-spacing: 0.08em; text-transform: uppercase; opacity: 0.85;">
                Scenario
              </div>
              <h2 style="margin: 10px 0 8px; font-size: 1.5rem; font-weight: 800; line-height: 1.1;">
                <%= scenario.title %>
              </h2>
              <p style="margin: 0; line-height: 1.6; font-size: 0.96rem; opacity: 0.92;">
                <%= scenario.subtitle %>
              </p>
            </div>

            <div style="padding: 20px;">
              <section
                :for={snapshot <- scenario.snapshots}
                style="background: #f8faff; border-radius: 18px; padding: 18px; border: 1px solid #d9e3f5; margin-bottom: 14px;"
              >
                <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 14px;">
                  <h3 style="margin: 0; font-size: 1rem; font-weight: 800; color: #21314a;">
                    <%= snapshot.label %>
                  </h3>
                  <span style={status_chip_style(snapshot.game_status)}>
                    <%= format_game_status(snapshot.game_status) %>
                  </span>
                </div>

                <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;">
                  <div style={metric_card_style()}>
                    <div style={metric_label_style()}>Turn</div>
                    <div style={metric_value_style()}><%= snapshot.turn %></div>
                  </div>
                  <div style={metric_card_style()}>
                    <div style={metric_label_style()}>Actions Left</div>
                    <div style={metric_value_style()}><%= snapshot.actions_left %></div>
                  </div>
                  <div style={metric_card_style()}>
                    <div style={metric_label_style()}>Score</div>
                    <div style={metric_value_style()}><%= snapshot.score %></div>
                  </div>
                  <div style={metric_card_style()}>
                    <div style={metric_label_style()}>Last Action</div>
                    <div style={metric_value_style()}><%= snapshot.last_action %></div>
                  </div>
                </div>

                <div style="display: flex; flex-wrap: wrap; gap: 10px; margin-top: 14px;">
                  <span style={detail_chip_style("#e8eefc", "#38518a")}>
                    artifact: <%= snapshot.artifact_status %>
                  </span>
                  <span style={detail_chip_style("#efe8fb", "#6940a5")}>
                    quality: <%= snapshot.artifact_quality %>
                  </span>
                </div>
              </section>
            </div>
          </article>
        </div>
      </section>
    </main>
    """
  end

  defp scenario_header_style(:progression) do
    "padding: 22px 22px 20px; background: linear-gradient(135deg, #1976d2 0%, #5aa9ff 100%); color: #ffffff;"
  end

  defp scenario_header_style(:winning) do
    "padding: 22px 22px 20px; background: linear-gradient(135deg, #2e7d32 0%, #66bb6a 100%); color: #ffffff;"
  end

  defp scenario_header_style(:losing) do
    "padding: 22px 22px 20px; background: linear-gradient(135deg, #c62828 0%, #ef5350 100%); color: #ffffff;"
  end

  defp status_chip_style(:in_progress) do
    "display: inline-flex; align-items: center; border-radius: 999px; padding: 7px 12px; background: #fff4de; color: #9a6500; font-size: 0.8rem; font-weight: 700;"
  end

  defp status_chip_style(:won) do
    "display: inline-flex; align-items: center; border-radius: 999px; padding: 7px 12px; background: #e0f2e4; color: #1f6a30; font-size: 0.8rem; font-weight: 700;"
  end

  defp status_chip_style({:lost, _reason}) do
    "display: inline-flex; align-items: center; border-radius: 999px; padding: 7px 12px; background: #fde7e9; color: #a12c35; font-size: 0.8rem; font-weight: 700;"
  end

  defp metric_card_style do
    "background: #ffffff; border-radius: 14px; padding: 12px; box-shadow: inset 0 0 0 1px #e3eaf7;"
  end

  defp metric_label_style do
    "font-size: 0.74rem; text-transform: uppercase; letter-spacing: 0.08em; color: #7c8da8; margin-bottom: 6px;"
  end

  defp metric_value_style do
    "font-size: 1.1rem; font-weight: 800; color: #203049;"
  end

  defp detail_chip_style(background, color) do
    "display: inline-flex; align-items: center; gap: 6px; background: #{background}; color: #{color}; border-radius: 999px; padding: 8px 12px; font-size: 0.82rem; font-weight: 700;"
  end

  defp format_game_status(:in_progress), do: "IN PROGRESS"
  defp format_game_status(:won), do: "WON"
  defp format_game_status({:lost, reason}), do: "LOST: #{reason}"
end

defmodule ArchaeologyRushWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", _assigns), do: "Not Found"
  def render("500.html", _assigns), do: "Internal Server Error"
  def render(_template, _assigns), do: "Unexpected Error"
end
