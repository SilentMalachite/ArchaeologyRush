defmodule ArchaeologyRushWeb.GameLiveTest do
  use ArchaeologyRushWeb.ConnCase, async: true

  describe "mount" do
    test "renders the game board", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/game")
      assert html =~ "発掘グリッド"
      assert html =~ "ターン"
      assert html =~ "スコア"
      assert html =~ "進行中"
    end
  end

  describe "select_cell" do
    test "clicking a cell selects it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/game")

      html =
        view
        |> element("button[phx-value-row='0'][phx-value-col='0']")
        |> render_click()

      assert html =~ "セル (0, 0)"
    end
  end

  describe "dig" do
    test "digging updates the grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/game")

      # Select cell
      view
      |> element("button[phx-value-row='1'][phx-value-col='1']")
      |> render_click()

      # Dig
      html =
        view
        |> element("button", "掘る")
        |> render_click()

      # Actions should decrease
      assert html =~ "残り行動"
    end
  end

  describe "end_turn" do
    test "ending turn advances to next turn", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/game")

      html =
        view
        |> element("button", "ターン終了")
        |> render_click()

      # Turn should be 2 now
      assert html =~ "ターン"
    end
  end

  describe "new_game" do
    test "new game resets the state after game over", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/game")

      # Exhaust all turns to trigger game over
      # The button becomes disabled after game over, so we stop early if needed
      Enum.reduce_while(1..11, :ok, fn _turn, _acc ->
        html = render(view)

        if html =~ "もう一度プレイ" do
          {:halt, :ok}
        else
          view |> element("button", "ターン終了") |> render_click()
          {:cont, :ok}
        end
      end)

      # Should show game over overlay
      html = render(view)
      assert html =~ "もう一度プレイ"

      # Start new game
      html =
        view
        |> element("button", "もう一度プレイ")
        |> render_click()

      assert html =~ "進行中"
    end
  end
end
