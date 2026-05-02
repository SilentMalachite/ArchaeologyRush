defmodule ArchaeologyRushWeb.GameLive do
  @moduledoc """
  インタラクティブ発掘ゲーム画面。

  4×4グリッドボードを中央に、発見物パネルを左、アクションパネルを右に配置する
  ダッシュボード型レイアウト。
  """

  use Phoenix.LiveView

  alias ArchaeologyRush.Excavation
  alias ArchaeologyRush.GameSession

  @layer_colors %{0 => "#e8d5b7", 1 => "#c4a876", 2 => "#8b7355"}
  @kind_icons %{
    pottery_shard: "🏺",
    stone_tool: "🪨",
    bone_fragment: "🦴",
    feature_mark: "📍"
  }
  @status_colors %{
    discovered: {"#fef3c7", "#92400e"},
    on_hold: {"#fed7aa", "#9a3412"},
    cataloged: {"#dbeafe", "#1e40af"},
    recovered: {"#d1fae5", "#065f46"}
  }
  @difficulty_presets %{
    easy: [
      max_turns: 12,
      actions_per_turn: 4,
      target_important_artifacts: 2,
      max_record_misses: 2
    ],
    normal: [
      max_turns: 10,
      actions_per_turn: 3,
      target_important_artifacts: 3,
      max_record_misses: 1
    ],
    hard: [
      max_turns: 8,
      actions_per_turn: 2,
      target_important_artifacts: 4,
      max_record_misses: 0
    ]
  }
  @difficulty_labels %{easy: "かんたん", normal: "ふつう", hard: "むずかしい"}
  @difficulty_order [:easy, :normal, :hard]

  @impl true
  def mount(_params, session, socket) do
    raw_game_options =
      session
      |> Map.get("game_options", [])

    difficulty = normalize_difficulty(Keyword.get(raw_game_options, :difficulty, :normal))
    {pid, excavation} = start_game_session(difficulty, raw_game_options)

    {:ok,
     assign(socket,
       game_pid: pid,
       excavation: excavation,
       difficulty: difficulty,
       selected_cell: nil,
       show_catalog_modal: false,
       catalog_target_id: nil,
       catalog_values: %{},
       catalog_errors: %{},
       show_final_report_modal: false,
       final_report_values: %{},
       final_report_errors: %{}
     )}
  end

  @impl true
  def handle_event("select_cell", %{"row" => row, "col" => col}, socket) do
    cell = {String.to_integer(row), String.to_integer(col)}

    selected =
      if socket.assigns.selected_cell == cell do
        nil
      else
        cell
      end

    {:noreply, assign(socket, :selected_cell, selected)}
  end

  def handle_event("change_difficulty", %{"difficulty" => difficulty}, socket) do
    difficulty = normalize_difficulty(difficulty)
    GenServer.stop(socket.assigns.game_pid, :normal)
    {pid, excavation} = start_game_session(difficulty)

    {:noreply,
     assign(socket,
       game_pid: pid,
       excavation: excavation,
       difficulty: difficulty,
       selected_cell: nil,
       show_catalog_modal: false,
       catalog_target_id: nil,
       catalog_values: %{},
       catalog_errors: %{},
       show_final_report_modal: false,
       final_report_values: %{},
       final_report_errors: %{}
     )}
  end

  def handle_event("dig", _params, socket) do
    cell = socket.assigns.selected_cell

    if cell do
      case GameSession.dig(socket.assigns.game_pid, cell) do
        {:ok, excavation, _artifact} ->
          {:noreply, assign(socket, excavation: excavation)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "セルを選択してください")}
    end
  end

  def handle_event("open_catalog", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       show_catalog_modal: true,
       catalog_target_id: String.to_integer(id),
       catalog_values: %{},
       catalog_errors: %{}
     )}
  end

  def handle_event("cancel_catalog", _params, socket) do
    {:noreply,
     assign(socket,
       show_catalog_modal: false,
       catalog_target_id: nil,
       catalog_values: %{},
       catalog_errors: %{}
     )}
  end

  def handle_event("submit_catalog", %{"catalog" => catalog}, socket) do
    id = socket.assigns.catalog_target_id
    errors = validate_catalog(catalog)

    if errors == %{} do
      attrs = %{operator_note: Map.get(catalog, "operator_note"), artifact_id: id}

      case GameSession.catalog(socket.assigns.game_pid, id, attrs) do
        {:ok, excavation, _artifact} ->
          {:noreply,
           assign(socket,
             excavation: excavation,
             show_catalog_modal: false,
             catalog_target_id: nil,
             catalog_values: %{},
             catalog_errors: %{}
           )}

        {:error, {:missing_required_fields, fields}} ->
          {:noreply,
           assign(socket,
             catalog_values: catalog,
             catalog_errors: catalog_missing_field_errors(fields)
           )}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    else
      {:noreply,
       assign(socket,
         catalog_values: catalog,
         catalog_errors: errors
       )}
    end
  end

  def handle_event("recover", %{"id" => id}, socket) do
    artifact_id = String.to_integer(id)

    case GameSession.recover(socket.assigns.game_pid, artifact_id) do
      {:ok, excavation, _artifact} ->
        {:noreply, assign(socket, excavation: excavation)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("end_turn", _params, socket) do
    excavation = GameSession.end_turn(socket.assigns.game_pid)
    {:noreply, assign(socket, excavation: excavation, selected_cell: nil)}
  end

  def handle_event("open_final_report", _params, socket) do
    {:noreply,
     assign(socket,
       show_final_report_modal: true,
       final_report_errors: %{}
     )}
  end

  def handle_event("cancel_final_report", _params, socket) do
    {:noreply,
     assign(socket,
       show_final_report_modal: false,
       final_report_errors: %{}
     )}
  end

  def handle_event("submit_final_report", %{"final_report" => report}, socket) do
    errors = validate_final_report(report)

    if errors == %{} do
      excavation = GameSession.complete_report(socket.assigns.game_pid)

      {:noreply,
       assign(socket,
         excavation: excavation,
         show_final_report_modal: false,
         final_report_values: report,
         final_report_errors: %{}
       )}
    else
      {:noreply,
       assign(socket,
         final_report_values: report,
         final_report_errors: errors
       )}
    end
  end

  def handle_event("new_game", _params, socket) do
    GenServer.stop(socket.assigns.game_pid, :normal)
    {pid, excavation} = start_game_session(socket.assigns.difficulty)

    {:noreply,
     assign(socket,
       game_pid: pid,
       excavation: excavation,
       selected_cell: nil,
       show_catalog_modal: false,
       catalog_target_id: nil,
       catalog_values: %{},
       catalog_errors: %{},
       show_final_report_modal: false,
       final_report_values: %{},
       final_report_errors: %{}
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main style="min-height: 100vh; background: #0a192f; padding: 16px; font-family: 'Noto Sans JP', 'Hiragino Sans', sans-serif; color: #ccd6f6;">
      <%!-- ステータスバー --%>
      <div style="max-width: 1200px; margin: 0 auto 12px; background: #16213e; border-radius: 12px; padding: 12px 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div style="display: flex; gap: 20px; align-items: center;">
          <span style="font-size: 0.85rem;">
            ターン <strong style="color: #64ffda;"><%= @excavation.site_state.turn %></strong> / <%= @excavation.max_turns %>
          </span>
          <span style="font-size: 0.85rem;">
            残り行動 <strong style="color: #64ffda;"><%= @excavation.site_state.actions_left %></strong>
          </span>
          <span style="font-size: 0.85rem;">
            スコア <strong style="color: #64ffda;"><%= @excavation.site_state.score %></strong>
          </span>
          <span style="font-size: 0.85rem;">
            記録ミス <strong style={"color: #{if @excavation.record_misses > 0, do: "#ff6b6b", else: "#64ffda"};"}><%= @excavation.record_misses %></strong> / <%= @excavation.max_record_misses %>
          </span>
          <span style="font-size: 0.85rem;">
            道具耐久 <strong style="color: #64ffda;"><%= @excavation.site_state.tool_durability %></strong>
          </span>
          <span style="font-size: 0.85rem;">
            難易度 <strong style="color: #64ffda;"><%= difficulty_label(@difficulty) %></strong>
          </span>
        </div>
        <span style={game_status_badge_style(Excavation.game_status(@excavation))}>
          <%= format_game_status(Excavation.game_status(@excavation)) %>
        </span>
      </div>

      <%!-- メインコンテンツ: 左パネル | グリッド | 右パネル --%>
      <div style="max-width: 1200px; margin: 0 auto; display: flex; gap: 12px;">
        <%!-- 発見物パネル（左） --%>
        <div style="width: 200px; flex-shrink: 0; background: #16213e; border-radius: 12px; padding: 14px; overflow-y: auto; max-height: 520px;">
          <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 10px;">発見物</div>
          <%= if map_size(@excavation.site_state.artifacts) == 0 do %>
            <div style="color: #4a5568; font-size: 0.8rem; text-align: center; padding: 20px 0;">
              まだ発見物はありません
            </div>
          <% else %>
            <div style="display: flex; flex-direction: column; gap: 8px;">
              <%= for {id, artifact} <- Enum.sort(@excavation.site_state.artifacts) do %>
                <div style="background: #233554; border-radius: 8px; padding: 10px;">
                  <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 6px;">
                    <span style="font-size: 1.1rem;"><%= kind_icon(artifact.kind) %></span>
                    <span style="font-size: 0.8rem; font-weight: 700;"><%= kind_label(artifact.kind) %></span>
                  </div>
                  <div style="display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 6px;">
                    <span style={artifact_status_chip_style(artifact.status)}>
                      <%= artifact_status_label(artifact.status) %>
                    </span>
                    <span style="font-size: 0.7rem; color: #8892b0; padding: 2px 6px; background: #1a2744; border-radius: 4px;">
                      <%= quality_label(artifact.quality) %>
                    </span>
                  </div>
                  <%= if artifact.status in [:discovered, :on_hold] and game_in_progress?(@excavation) do %>
                    <button
                      phx-click="open_catalog"
                      phx-value-id={id}
                      style="width: 100%; padding: 5px; background: #3b82f6; color: white; border: none; border-radius: 4px; font-size: 0.75rem; cursor: pointer;"
                    >
                      📋 記録
                    </button>
                  <% end %>
                  <%= if artifact.status == :cataloged and game_in_progress?(@excavation) do %>
                    <button
                      phx-click="recover"
                      phx-value-id={id}
                      style="width: 100%; padding: 5px; background: #10b981; color: white; border: none; border-radius: 4px; font-size: 0.75rem; cursor: pointer;"
                    >
                      📦 回収
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- グリッドボード（中央） --%>
        <div style="flex: 1; background: #16213e; border-radius: 12px; padding: 14px;">
          <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 10px;">発掘グリッド (4×4)</div>
          <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; aspect-ratio: 1;">
            <%= for row <- 0..3, col <- 0..3 do %>
              <% cell = {row, col} %>
              <% progress = Map.get(@excavation.site_state.cell_progress, cell, 0) %>
              <% selected = @selected_cell == cell %>
              <% cell_artifacts = artifacts_at_cell(@excavation.site_state.artifacts, cell) %>
              <button
                phx-click="select_cell"
                phx-value-row={row}
                phx-value-col={col}
                disabled={not game_in_progress?(@excavation)}
                style={"display: flex; flex-direction: column; align-items: center; justify-content: center; border-radius: 8px; border: 3px solid #{if selected, do: "#64ffda", else: "transparent"}; background: #{cell_color(progress)}; cursor: #{if game_in_progress?(@excavation), do: "pointer", else: "default"}; min-height: 80px; transition: border-color 0.15s;"}
              >
                <span style={"font-size: 0.7rem; color: #{if progress >= 2, do: "#e8d5b7", else: "#5c4a32"}; font-weight: 600;"}>
                  <%= layer_label(progress) %>
                </span>
                <%= if cell_artifacts != [] do %>
                  <div style="display: flex; gap: 2px; margin-top: 4px;">
                    <%= for a <- cell_artifacts do %>
                      <span style="font-size: 0.9rem;" title={"#{kind_label(a.kind)} (#{a.status})"}><%= kind_icon(a.kind) %></span>
                    <% end %>
                  </div>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>

        <%!-- アクションパネル（右） --%>
        <div style="width: 180px; flex-shrink: 0; display: flex; flex-direction: column; gap: 10px;">
          <div style="background: #16213e; border-radius: 12px; padding: 14px;">
            <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 10px;">アクション</div>
            <div style="display: flex; flex-direction: column; gap: 6px;">
              <button
                phx-click="dig"
                disabled={@selected_cell == nil or @excavation.site_state.actions_left == 0 or not game_in_progress?(@excavation)}
                style={"padding: 10px; border-radius: 8px; border: none; font-size: 0.85rem; font-weight: 700; cursor: #{if @selected_cell != nil and @excavation.site_state.actions_left > 0 and game_in_progress?(@excavation), do: "pointer", else: "not-allowed"}; background: #{if @selected_cell != nil and @excavation.site_state.actions_left > 0 and game_in_progress?(@excavation), do: "#64ffda", else: "#233554"}; color: #{if @selected_cell != nil and @excavation.site_state.actions_left > 0 and game_in_progress?(@excavation), do: "#0a192f", else: "#4a5568"};"}
              >
                ⛏ 掘る
              </button>
              <button
                phx-click="end_turn"
                disabled={not game_in_progress?(@excavation)}
                style={"padding: 10px; border-radius: 8px; border: none; font-size: 0.85rem; font-weight: 700; cursor: #{if game_in_progress?(@excavation), do: "pointer", else: "not-allowed"}; background: #{if game_in_progress?(@excavation), do: "#233554", else: "#1a2744"}; color: #{if game_in_progress?(@excavation), do: "#ccd6f6", else: "#4a5568"};"}
              >
                ⏭ ターン終了
                <%= if has_discovered_artifacts?(@excavation) do %>
                  <div style="font-size: 0.65rem; color: #ff6b6b; margin-top: 2px;">⚠ 未記録の発見物あり</div>
                <% end %>
              </button>
              <button
                phx-click="open_final_report"
                disabled={not can_complete_report?(@excavation)}
                style={"padding: 10px; border-radius: 8px; border: none; font-size: 0.85rem; font-weight: 700; cursor: #{if can_complete_report?(@excavation), do: "pointer", else: "not-allowed"}; background: #{if can_complete_report?(@excavation), do: "#fbbf24", else: "#233554"}; color: #{if can_complete_report?(@excavation), do: "#0a192f", else: "#4a5568"};"}
              >
                📝 最終レポート
              </button>
            </div>
          </div>

          <div style="background: #16213e; border-radius: 12px; padding: 14px;">
            <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 10px;">難易度</div>
            <div style="display: flex; flex-direction: column; gap: 6px;">
              <%= for difficulty <- difficulty_order() do %>
                <button
                  phx-click="change_difficulty"
                  phx-value-difficulty={difficulty}
                  style={difficulty_button_style(@difficulty, difficulty)}
                >
                  <%= difficulty_label(difficulty) %>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- 選択セル情報 --%>
          <%= if @selected_cell do %>
            <div style="background: #16213e; border-radius: 12px; padding: 14px;">
              <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 6px;">選択中</div>
              <div style="color: #ccd6f6; font-size: 0.85rem;">
                セル (<%= elem(@selected_cell, 0) %>, <%= elem(@selected_cell, 1) %>)
              </div>
              <div style="color: #8892b0; font-size: 0.75rem; margin-top: 4px;">
                <% progress = Map.get(@excavation.site_state.cell_progress, @selected_cell, 0) %>
                層: <%= layer_label(progress) %>
                <%= if progress >= 3 do %>
                  (掘削完了)
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- ログパネル --%>
      <div style="max-width: 1200px; margin: 12px auto 0; background: #16213e; border-radius: 12px; padding: 14px;">
        <div style="color: #8892b0; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 8px;">ログ</div>
        <div style="max-height: 100px; overflow-y: auto; display: flex; flex-direction: column; gap: 4px;">
          <%= for log <- Enum.take(@excavation.site_state.turn_logs, -5) |> Enum.reverse() do %>
            <div style="color: #8892b0; font-size: 0.78rem;">
              [ターン<%= log.turn %>] <%= format_log(log) %>
            </div>
          <% end %>
          <%= if @excavation.site_state.turn_logs == [] do %>
            <div style="color: #4a5568; font-size: 0.78rem;">ログはまだありません</div>
          <% end %>
        </div>
      </div>

      <%!-- ゲーム終了オーバーレイ --%>
      <%= if not game_in_progress?(@excavation) do %>
        <div style="position: fixed; inset: 0; background: rgba(10, 25, 47, 0.85); display: flex; align-items: center; justify-content: center; z-index: 100;">
          <div style="background: #16213e; border-radius: 20px; padding: 40px; text-align: center; max-width: 400px;">
            <div style={"font-size: 3rem; margin-bottom: 16px;"}>
              <%= if Excavation.game_status(@excavation) == :won, do: "🏆", else: "💀" %>
            </div>
            <h2 style={"font-size: 1.5rem; font-weight: 800; margin-bottom: 8px; color: #{if Excavation.game_status(@excavation) == :won, do: "#64ffda", else: "#ff6b6b"};"}>
              <%= if Excavation.game_status(@excavation) == :won, do: "発掘成功！", else: "発掘失敗..." %>
            </h2>
            <p style="color: #8892b0; font-size: 0.9rem; margin-bottom: 4px;">
              スコア: <strong style="color: #ccd6f6;"><%= @excavation.site_state.score %></strong>
            </p>
            <p style="color: #8892b0; font-size: 0.85rem; margin-bottom: 24px;">
              <%= game_over_reason(Excavation.game_status(@excavation)) %>
            </p>
            <button
              phx-click="new_game"
              style="padding: 12px 32px; background: #64ffda; color: #0a192f; border: none; border-radius: 10px; font-size: 1rem; font-weight: 700; cursor: pointer;"
            >
              🔄 もう一度プレイ
            </button>
          </div>
        </div>
      <% end %>

      <%!-- Catalogモーダル --%>
      <%= if @show_catalog_modal do %>
        <% catalog_target = catalog_target_artifact(@excavation, @catalog_target_id) %>
        <div style="position: fixed; inset: 0; background: rgba(10, 25, 47, 0.85); display: flex; align-items: center; justify-content: center; z-index: 100;">
          <div style="background: #16213e; border-radius: 16px; padding: 30px; max-width: 440px; width: 90%;">
            <h3 style="color: #ccd6f6; font-size: 1.1rem; font-weight: 700; margin-bottom: 16px;">📋 アーティファクト記録</h3>
            <%= if catalog_target do %>
              <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-bottom: 14px;">
                <%= catalog_fact("遺物ID", catalog_target.id) %>
                <%= catalog_fact("座標", format_cell(catalog_target.coordinate)) %>
                <%= catalog_fact("深度", catalog_target.depth) %>
                <%= catalog_fact("層ID", catalog_target.layer_id) %>
                <%= catalog_fact("発見ターン", catalog_target.discovered_turn) %>
              </div>
            <% end %>
            <form id="catalog-form" phx-submit="submit_catalog">
              <label style="display: block; color: #8892b0; font-size: 0.8rem; margin-bottom: 6px;">
                担当者メモ
              </label>
              <textarea
                name="catalog[operator_note]"
                rows="3"
                style="width: 100%; background: #233554; color: #ccd6f6; border: 1px solid #344563; border-radius: 8px; padding: 10px; font-size: 0.85rem; resize: vertical;"
                placeholder="観察メモを入力..."
              ><%= Map.get(@catalog_values, "operator_note", "") %></textarea>
              <%= if error = Map.get(@catalog_errors, "operator_note") do %>
                <div style="color: #ff6b6b; font-size: 0.75rem; margin-top: 6px;"><%= error %></div>
              <% end %>
              <div style="display: flex; gap: 8px; margin-top: 16px;">
                <button
                  type="submit"
                  style="flex: 1; padding: 10px; background: #3b82f6; color: white; border: none; border-radius: 8px; font-size: 0.85rem; font-weight: 700; cursor: pointer;"
                >
                  記録する
                </button>
                <button
                  type="button"
                  phx-click="cancel_catalog"
                  style="flex: 1; padding: 10px; background: #233554; color: #8892b0; border: none; border-radius: 8px; font-size: 0.85rem; cursor: pointer;"
                >
                  キャンセル
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- 最終レポートモーダル --%>
      <%= if @show_final_report_modal do %>
        <div style="position: fixed; inset: 0; background: rgba(10, 25, 47, 0.85); display: flex; align-items: center; justify-content: center; z-index: 100;">
          <div style="background: #16213e; border-radius: 16px; padding: 30px; max-width: 460px; width: 90%;">
            <h3 style="color: #ccd6f6; font-size: 1.1rem; font-weight: 700; margin-bottom: 16px;">📝 最終レポート</h3>
            <form id="final-report-form" phx-submit="submit_final_report">
              <%= report_text_input("investigator_name", "調査者名", @final_report_values, @final_report_errors) %>
              <%= report_textarea("findings", "所見", @final_report_values, @final_report_errors) %>
              <%= report_textarea("important_artifact_summary", "重要遺物の要約", @final_report_values, @final_report_errors) %>
              <%= report_number_input("survey_days", "調査日数", @final_report_values, @final_report_errors) %>
              <div style="display: flex; gap: 8px; margin-top: 16px;">
                <button
                  type="submit"
                  style="flex: 1; padding: 10px; background: #fbbf24; color: #0a192f; border: none; border-radius: 8px; font-size: 0.85rem; font-weight: 700; cursor: pointer;"
                >
                  レポート提出
                </button>
                <button
                  type="button"
                  phx-click="cancel_final_report"
                  style="flex: 1; padding: 10px; background: #233554; color: #8892b0; border: none; border-radius: 8px; font-size: 0.85rem; cursor: pointer;"
                >
                  キャンセル
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </main>
    """
  end

  # --- Helper functions ---

  defp start_game_session(difficulty, options \\ []) do
    game_options =
      difficulty
      |> difficulty_options()
      |> Keyword.merge(Keyword.delete(options, :difficulty))
      |> resolve_game_options()

    {:ok, pid} = GameSession.start_link(game_options)
    {pid, GameSession.get_state(pid)}
  end

  defp normalize_difficulty(difficulty) when difficulty in [:easy, "easy"], do: :easy
  defp normalize_difficulty(difficulty) when difficulty in [:hard, "hard"], do: :hard
  defp normalize_difficulty(_difficulty), do: :normal

  defp difficulty_options(difficulty), do: Map.fetch!(@difficulty_presets, difficulty)
  defp difficulty_label(difficulty), do: Map.fetch!(@difficulty_labels, difficulty)
  defp difficulty_order, do: @difficulty_order

  defp difficulty_button_style(selected, difficulty) do
    if selected == difficulty do
      "padding: 8px; border-radius: 8px; border: none; font-size: 0.8rem; font-weight: 700; cursor: pointer; background: #64ffda; color: #0a192f;"
    else
      "padding: 8px; border-radius: 8px; border: none; font-size: 0.8rem; font-weight: 700; cursor: pointer; background: #233554; color: #ccd6f6;"
    end
  end

  defp resolve_game_options(options) do
    {discovery_mode, options} = Keyword.pop(options, :discovery_mode)

    case discovery_mode do
      "always" ->
        Keyword.put(options, :discovery_fn, fn _, _, _ ->
          %{kind: :pottery_shard, quality: :good}
        end)

      "none" ->
        Keyword.put(options, :discovery_fn, fn _, _, _ -> nil end)

      _other ->
        options
    end
  end

  defp game_in_progress?(excavation) do
    Excavation.game_status(excavation) == :in_progress
  end

  defp has_discovered_artifacts?(excavation) do
    excavation.site_state.artifacts
    |> Map.values()
    |> Enum.any?(&(&1.status == :discovered))
  end

  defp can_complete_report?(excavation) do
    game_in_progress?(excavation) and not excavation.final_report_complete and
      recovered_important_count(excavation) >= excavation.target_important_artifacts
  end

  defp recovered_important_count(excavation) do
    excavation.site_state.artifacts
    |> Map.values()
    |> Enum.count(fn a -> a.status == :recovered and a.kind != :feature_mark end)
  end

  defp validate_catalog(catalog) do
    if blank?(Map.get(catalog, "operator_note")) do
      %{"operator_note" => "担当者メモを入力してください"}
    else
      %{}
    end
  end

  defp catalog_missing_field_errors(fields) do
    Map.new(fields, fn field -> {Atom.to_string(field), catalog_field_error(field)} end)
  end

  defp catalog_field_error(:operator_note), do: "担当者メモを入力してください"
  defp catalog_field_error(field), do: "#{field}を確認してください"

  defp catalog_target_artifact(excavation, artifact_id) do
    Map.get(excavation.site_state.artifacts, artifact_id)
  end

  defp catalog_fact(label, value) do
    assigns = %{label: label, value: value}

    ~H"""
    <div style="background: #233554; border-radius: 8px; padding: 8px;">
      <div style="color: #8892b0; font-size: 0.72rem; margin-bottom: 3px;"><%= @label %></div>
      <div style="color: #ccd6f6; font-size: 0.82rem; font-weight: 700;"><%= @value %></div>
    </div>
    """
  end

  defp format_cell({row, col}), do: "(#{row}, #{col})"
  defp format_cell(_cell), do: "-"

  defp validate_final_report(report) do
    [
      {"investigator_name", "調査者名を入力してください"},
      {"findings", "所見を入力してください"},
      {"important_artifact_summary", "重要遺物の要約を入力してください"},
      {"survey_days", "調査日数を入力してください"}
    ]
    |> Enum.reduce(%{}, fn {field, message}, errors ->
      if blank?(Map.get(report, field)) do
        Map.put(errors, field, message)
      else
        errors
      end
    end)
  end

  defp blank?(value) when value in [nil, ""], do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp final_report_value(values, field), do: Map.get(values, field, "")

  defp final_report_error(errors, field), do: Map.get(errors, field)

  defp report_text_input(field, label, values, errors) do
    assigns = %{
      field: field,
      label: label,
      value: final_report_value(values, field),
      error: final_report_error(errors, field)
    }

    ~H"""
    <label style="display: block; color: #8892b0; font-size: 0.8rem; margin-bottom: 6px;"><%= @label %></label>
    <input
      type="text"
      name={"final_report[#{@field}]"}
      value={@value}
      style="width: 100%; background: #233554; color: #ccd6f6; border: 1px solid #344563; border-radius: 8px; padding: 10px; font-size: 0.85rem; margin-bottom: 4px;"
    />
    <%= if @error do %>
      <div style="color: #ff6b6b; font-size: 0.75rem; margin-bottom: 10px;"><%= @error %></div>
    <% else %>
      <div style="height: 10px;"></div>
    <% end %>
    """
  end

  defp report_number_input(field, label, values, errors) do
    assigns = %{
      field: field,
      label: label,
      value: final_report_value(values, field),
      error: final_report_error(errors, field)
    }

    ~H"""
    <label style="display: block; color: #8892b0; font-size: 0.8rem; margin-bottom: 6px;"><%= @label %></label>
    <input
      type="number"
      min="1"
      name={"final_report[#{@field}]"}
      value={@value}
      style="width: 100%; background: #233554; color: #ccd6f6; border: 1px solid #344563; border-radius: 8px; padding: 10px; font-size: 0.85rem; margin-bottom: 4px;"
    />
    <%= if @error do %>
      <div style="color: #ff6b6b; font-size: 0.75rem; margin-bottom: 10px;"><%= @error %></div>
    <% else %>
      <div style="height: 10px;"></div>
    <% end %>
    """
  end

  defp report_textarea(field, label, values, errors) do
    assigns = %{
      field: field,
      label: label,
      value: final_report_value(values, field),
      error: final_report_error(errors, field)
    }

    ~H"""
    <label style="display: block; color: #8892b0; font-size: 0.8rem; margin-bottom: 6px;"><%= @label %></label>
    <textarea
      name={"final_report[#{@field}]"}
      rows="3"
      style="width: 100%; background: #233554; color: #ccd6f6; border: 1px solid #344563; border-radius: 8px; padding: 10px; font-size: 0.85rem; resize: vertical; margin-bottom: 4px;"
    ><%= @value %></textarea>
    <%= if @error do %>
      <div style="color: #ff6b6b; font-size: 0.75rem; margin-bottom: 10px;"><%= @error %></div>
    <% else %>
      <div style="height: 10px;"></div>
    <% end %>
    """
  end

  defp cell_color(progress) when progress >= 3, do: "#6b5b47"
  defp cell_color(progress), do: Map.get(@layer_colors, progress, "#e8d5b7")

  defp layer_label(0), do: "上層"
  defp layer_label(1), do: "中層"
  defp layer_label(2), do: "下層"
  defp layer_label(_), do: "完了"

  defp kind_icon(kind), do: Map.get(@kind_icons, kind, "❓")

  defp kind_label(:pottery_shard), do: "土器片"
  defp kind_label(:stone_tool), do: "石器"
  defp kind_label(:bone_fragment), do: "骨片"
  defp kind_label(:feature_mark), do: "遺構痕"

  defp quality_label(:poor), do: "低品質"
  defp quality_label(:fair), do: "普通"
  defp quality_label(:good), do: "良好"
  defp quality_label(:excellent), do: "優秀"

  defp artifact_status_label(:discovered), do: "発見"
  defp artifact_status_label(:on_hold), do: "保留"
  defp artifact_status_label(:cataloged), do: "記録済"
  defp artifact_status_label(:recovered), do: "回収済"

  defp artifact_status_chip_style(status) do
    {bg, fg} = Map.get(@status_colors, status, {"#e2e8f0", "#4a5568"})

    "font-size: 0.7rem; font-weight: 700; padding: 2px 6px; border-radius: 4px; background: #{bg}; color: #{fg};"
  end

  defp artifacts_at_cell(artifacts, cell) do
    artifacts
    |> Map.values()
    |> Enum.filter(&(&1.coordinate == cell))
  end

  defp game_status_badge_style(:in_progress) do
    "padding: 6px 12px; border-radius: 999px; font-size: 0.78rem; font-weight: 700; background: #233554; color: #64ffda;"
  end

  defp game_status_badge_style(:won) do
    "padding: 6px 12px; border-radius: 999px; font-size: 0.78rem; font-weight: 700; background: #065f46; color: #d1fae5;"
  end

  defp game_status_badge_style({:lost, _}) do
    "padding: 6px 12px; border-radius: 999px; font-size: 0.78rem; font-weight: 700; background: #7f1d1d; color: #fecaca;"
  end

  defp format_game_status(:in_progress), do: "進行中"
  defp format_game_status(:won), do: "勝利"
  defp format_game_status({:lost, :turn_limit_reached}), do: "敗北: ターン上限"
  defp format_game_status({:lost, :too_many_record_misses}), do: "敗北: 記録ミス超過"

  defp game_over_reason(:won), do: "重要なアーティファクトの回収に成功しました"
  defp game_over_reason({:lost, :turn_limit_reached}), do: "ターン上限に達しました"
  defp game_over_reason({:lost, :too_many_record_misses}), do: "記録ミスが多すぎました"

  defp format_log(%{action: :dig, cell: {r, c}, layer: layer, penalty_applied: true}) do
    "セル(#{r},#{c})を掘削 → #{layer_label_from_atom(layer)} / 層混入ペナルティ -5点"
  end

  defp format_log(%{action: :dig, cell: {r, c}, layer: layer}) do
    "セル(#{r},#{c})を掘削 → #{layer_label_from_atom(layer)}"
  end

  defp format_log(%{action: :catalog, artifact_id: id}) do
    "アーティファクト##{id}を記録"
  end

  defp format_log(%{action: :recover, artifact_id: id, score_gain: gain}) do
    "アーティファクト##{id}を回収 (+#{gain}点)"
  end

  defp format_log(%{action: :end_turn, next_turn: t, record_misses: misses}) when misses > 0 do
    "ターン#{t}開始 / 記録ミス +#{misses}"
  end

  defp format_log(%{action: :end_turn, next_turn: t}) do
    "ターン#{t}開始"
  end

  defp format_log(_), do: ""

  defp layer_label_from_atom(:upper), do: "上層"
  defp layer_label_from_atom(:middle), do: "中層"
  defp layer_label_from_atom(:lower), do: "下層"

  defp error_message(:no_actions_left), do: "行動ポイントが残っていません"
  defp error_message(:cell_fully_excavated), do: "このセルは既に掘削完了です"
  defp error_message(:artifact_not_found), do: "アーティファクトが見つかりません"
  defp error_message(:artifact_not_cataloged), do: "先に記録してください"
  defp error_message({:missing_required_fields, fields}), do: "必須項目が不足: #{inspect(fields)}"
  defp error_message(reason), do: "エラー: #{inspect(reason)}"
end
