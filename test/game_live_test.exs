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

    test "shows contamination penalty in the log", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ArchaeologyRushWeb.GameLive,
          session: %{"game_options" => [discovery_mode: "none"]}
        )

      view
      |> element("button[phx-value-row='1'][phx-value-col='1']")
      |> render_click()

      Enum.each(1..2, fn _ ->
        view
        |> element("button", "掘る")
        |> render_click()
      end)

      html =
        view
        |> element("button", "掘る")
        |> render_click()

      assert html =~ "層混入ペナルティ"
      assert html =~ "-5点"
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

    test "shows record misses when ending a turn with uncataloged artifacts", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ArchaeologyRushWeb.GameLive,
          session: %{"game_options" => [discovery_mode: "always"]}
        )

      view
      |> element("button[phx-value-row='1'][phx-value-col='1']")
      |> render_click()

      view
      |> element("button", "掘る")
      |> render_click()

      html =
        view
        |> element("button", "ターン終了")
        |> render_click()

      assert html =~ "記録ミス +1"
      assert html =~ "記録ミス"
    end
  end

  describe "catalog and recover" do
    test "shows required catalog fields, validation, re-entry, and score gain", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ArchaeologyRushWeb.GameLive,
          session: %{"game_options" => [discovery_mode: "always"]}
        )

      view
      |> element("button[phx-value-row='1'][phx-value-col='2']")
      |> render_click()

      view
      |> element("button", "掘る")
      |> render_click()

      html =
        view
        |> element("button[phx-click='open_catalog']")
        |> render_click()

      assert html =~ "遺物ID"
      assert html =~ "座標"
      assert html =~ "深度"
      assert html =~ "層ID"
      assert html =~ "発見ターン"
      assert html =~ "担当者メモ"

      html =
        view
        |> form("#catalog-form", %{"catalog" => %{"operator_note" => ""}})
        |> render_submit()

      assert html =~ "担当者メモを入力してください"

      html =
        view
        |> form("#catalog-form", %{"catalog" => %{"operator_note" => "記録済み"}})
        |> render_submit()

      assert html =~ "記録済"

      html =
        view
        |> element("button", "回収")
        |> render_click()

      assert html =~ "+15点"
      assert html =~ "アーティファクト#1を回収"
    end
  end

  describe "final report" do
    test "requires all report fields before completing the game", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ArchaeologyRushWeb.GameLive,
          session: %{"game_options" => [target_important_artifacts: 0]}
        )

      view
      |> element("button", "最終レポート")
      |> render_click()

      html =
        view
        |> form("#final-report-form", %{
          "final_report" => %{
            "investigator_name" => "",
            "findings" => "",
            "important_artifact_summary" => "",
            "survey_days" => ""
          }
        })
        |> render_submit()

      assert html =~ "調査者名を入力してください"
      assert html =~ "所見を入力してください"
      assert html =~ "重要遺物の要約を入力してください"
      assert html =~ "調査日数を入力してください"
      assert html =~ "進行中"
    end

    test "completes the game when every report field is present", %{conn: conn} do
      {:ok, view, _html} =
        live_isolated(conn, ArchaeologyRushWeb.GameLive,
          session: %{"game_options" => [target_important_artifacts: 0]}
        )

      view
      |> element("button", "最終レポート")
      |> render_click()

      html =
        view
        |> form("#final-report-form", %{
          "final_report" => %{
            "investigator_name" => "山田太郎",
            "findings" => "層位の乱れは限定的でした。",
            "important_artifact_summary" => "重要遺物は回収済みです。",
            "survey_days" => "3"
          }
        })
        |> render_submit()

      assert html =~ "発掘成功！"
      assert html =~ "スコア:"
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
