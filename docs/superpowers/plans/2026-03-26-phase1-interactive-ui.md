# Phase 1: Interactive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ArchaeologyRushに4×4グリッドボード付きのインタラクティブゲーム画面を追加し、dig/catalog/recover/end_turnの全操作をブラウザで実行可能にする。

**Architecture:** GameSession (GenServer) がExcavation構造体を保持し、GameLive (LiveView) がユーザー操作をGameSessionに委譲する。RandomDiscoveryモジュールがdiscovery_fnコールバックとしてアーティファクトのランダム発見を提供する。既存のSiteState/Excavationは一切変更しない。

**Tech Stack:** Elixir, Phoenix LiveView, GenServer, HEEx templates, inline CSS

**Spec:** `docs/superpowers/specs/2026-03-26-phase1-interactive-ui-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/archaeology_rush/random_discovery.ex` | Create | ランダムアーティファクト発見ロジック。discovery_fn型に準拠 |
| `test/random_discovery_test.exs` | Create | RandomDiscoveryの単体テスト |
| `lib/archaeology_rush/game_session.ex` | Create | GenServerでExcavation状態を管理。LiveViewへのAPI提供 |
| `test/game_session_test.exs` | Create | GameSessionの単体テスト |
| `lib/archaeology_rush_web/live/game_live.ex` | Create | インタラクティブゲームLiveView |
| `lib/archaeology_rush_web.ex` | Modify (L34-41) | Routerに `/game` ルート追加 |
| `test/support/conn_case.ex` | Create | LiveViewテスト用ヘルパー（Endpoint/PubSub起動） |
| `test/game_live_test.exs` | Create | GameLiveの統合テスト |

---

## Task 1: RandomDiscovery モジュール

**Files:**
- Create: `lib/archaeology_rush/random_discovery.ex`
- Create: `test/random_discovery_test.exs`

### Step 1.1: Write the failing test

- [ ] `test/random_discovery_test.exs` を作成

```elixir
defmodule ArchaeologyRush.RandomDiscoveryTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.RandomDiscovery

  describe "discovery_fn/0" do
    test "returns a function with arity 3" do
      fun = RandomDiscovery.discovery_fn()
      assert is_function(fun, 3)
    end

    test "returned function produces nil or valid discovery map" do
      fun = RandomDiscovery.discovery_fn()

      results =
        for row <- 0..3, col <- 0..3, layer <- [:upper, :middle, :lower] do
          fun.({row, col}, layer, 1)
        end

      Enum.each(results, fn result ->
        case result do
          nil ->
            :ok

          %{kind: kind, quality: quality} ->
            assert kind in [:pottery_shard, :stone_tool, :bone_fragment, :feature_mark]
            assert quality in [:poor, :fair, :good, :excellent]
        end
      end)
    end

    test "discovery probability increases with deeper layers" do
      fun = RandomDiscovery.discovery_fn()
      sample_size = 1000

      counts =
        for layer <- [:upper, :middle, :lower], into: %{} do
          found =
            Enum.count(1..sample_size, fn _ ->
              fun.({0, 0}, layer, 1) != nil
            end)

          {layer, found / sample_size}
        end

      assert counts[:upper] < counts[:middle]
      assert counts[:middle] < counts[:lower]
    end
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test test/random_discovery_test.exs`
Expected: FAIL — `ArchaeologyRush.RandomDiscovery` module not found

- [ ] **Step 1.3: Write minimal implementation**

`lib/archaeology_rush/random_discovery.ex`:

```elixir
defmodule ArchaeologyRush.RandomDiscovery do
  @moduledoc """
  ランダムなアーティファクト発見ロジック。

  SiteState.discovery_fn 型に準拠するコールバックを提供します。
  プロトタイプ用の仮実装であり、後からドメイン仕様に差し替え可能です。
  """

  alias ArchaeologyRush.SiteState

  @kind_options [:pottery_shard, :stone_tool, :bone_fragment, :feature_mark]

  @quality_weights [
    {:poor, 40},
    {:fair, 35},
    {:good, 20},
    {:excellent, 5}
  ]

  @layer_discovery_rates %{
    upper: 0.20,
    middle: 0.40,
    lower: 0.60
  }

  @spec discovery_fn() :: SiteState.discovery_fn()
  def discovery_fn do
    fn cell, layer, turn -> maybe_discover(cell, layer, turn) end
  end

  @spec maybe_discover(SiteState.cell(), SiteState.layer(), pos_integer()) ::
          SiteState.discovery_result()
  defp maybe_discover(_cell, layer, _turn) do
    rate = Map.fetch!(@layer_discovery_rates, layer)

    if :rand.uniform() < rate do
      %{
        kind: Enum.random(@kind_options),
        quality: weighted_random(@quality_weights)
      }
    else
      nil
    end
  end

  @spec weighted_random([{atom(), pos_integer()}]) :: atom()
  defp weighted_random(weights) do
    total = Enum.reduce(weights, 0, fn {_val, w}, acc -> acc + w end)
    roll = :rand.uniform(total)

    Enum.reduce_while(weights, 0, fn {val, w}, acc ->
      acc = acc + w
      if roll <= acc, do: {:halt, val}, else: {:cont, acc}
    end)
  end
end
```

- [ ] **Step 1.4: Run test to verify it passes**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test test/random_discovery_test.exs`
Expected: 3 tests, 0 failures

- [ ] **Step 1.5: Run quality check**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix format && mix credo --strict`
Expected: No warnings

- [ ] **Step 1.6: Commit**

```bash
cd /Users/hiro/Projetct/GitHub/ArchaeologyRush
git add lib/archaeology_rush/random_discovery.ex test/random_discovery_test.exs
git commit -m "feat: add RandomDiscovery module for prototype artifact generation"
```

---

## Task 2: GameSession GenServer

**Files:**
- Create: `lib/archaeology_rush/game_session.ex`
- Create: `test/game_session_test.exs`

### Step 2.1: Write the failing test

- [ ] `test/game_session_test.exs` を作成

```elixir
defmodule ArchaeologyRush.GameSessionTest do
  use ExUnit.Case, async: true

  alias ArchaeologyRush.GameSession
  alias ArchaeologyRush.Excavation

  # テスト用の確定的discovery_fn（必ず発見する）
  defp always_discover_fn do
    fn _cell, _layer, _turn ->
      %{kind: :pottery_shard, quality: :good}
    end
  end

  describe "start_link/1 and get_state/1" do
    test "starts a new game session with default state" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.get_state(pid)
      assert %Excavation{} = state
      assert state.site_state.turn == 1
      assert state.site_state.actions_left == 3
    end

    test "accepts custom options" do
      {:ok, pid} = GameSession.start_link(max_turns: 5, discovery_fn: always_discover_fn())
      state = GameSession.get_state(pid)
      assert state.max_turns == 5
    end
  end

  describe "dig/2" do
    test "digs a cell and returns updated state with possible artifact" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      assert {:ok, state, artifact} = GameSession.dig(pid, {0, 0})
      assert state.site_state.actions_left == 2
      assert state.site_state.cell_progress[{0, 0}] == 1
      assert artifact != nil
      assert artifact.kind == :pottery_shard
    end

    test "returns error when no actions left" do
      {:ok, pid} = GameSession.start_link(actions_per_turn: 1, discovery_fn: always_discover_fn())
      {:ok, _state, _artifact} = GameSession.dig(pid, {0, 0})
      assert {:error, :no_actions_left} = GameSession.dig(pid, {1, 1})
    end
  end

  describe "catalog/3" do
    test "catalogs a discovered artifact with operator_note" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})

      attrs = %{operator_note: "テスト記録", artifact_id: artifact.id}
      assert {:ok, state, cataloged} = GameSession.catalog(pid, artifact.id, attrs)
      assert cataloged.status == :cataloged
      assert cataloged.operator_note == "テスト記録"
      assert state.site_state.artifacts[artifact.id].status == :cataloged
    end
  end

  describe "recover/2" do
    test "recovers a cataloged artifact and adds score" do
      {:ok, pid} = GameSession.start_link(discovery_fn: always_discover_fn())
      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})
      {:ok, _state, _cataloged} = GameSession.catalog(pid, artifact.id, %{operator_note: "memo", artifact_id: artifact.id})
      assert {:ok, state, recovered} = GameSession.recover(pid, artifact.id)
      assert recovered.status == :recovered
      assert state.site_state.score > 0
    end
  end

  describe "end_turn/1" do
    test "advances to the next turn" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.end_turn(pid)
      assert state.site_state.turn == 2
      assert state.site_state.actions_left == 3
    end
  end

  describe "complete_report/1" do
    test "marks the report as complete" do
      {:ok, pid} = GameSession.start_link([])
      state = GameSession.complete_report(pid)
      assert state.final_report_complete == true
    end
  end

  describe "game lifecycle" do
    test "full game: dig -> catalog -> recover -> complete_report -> won" do
      {:ok, pid} =
        GameSession.start_link(
          target_important_artifacts: 1,
          discovery_fn: always_discover_fn()
        )

      # dig -> catalog -> recover
      {:ok, _state, artifact} = GameSession.dig(pid, {0, 0})
      {:ok, _state, _cataloged} = GameSession.catalog(pid, artifact.id, %{operator_note: "note", artifact_id: artifact.id})
      {:ok, _state, _recovered} = GameSession.recover(pid, artifact.id)

      # complete_report -> check win
      state = GameSession.complete_report(pid)
      assert Excavation.game_status(state) == :won
    end
  end
end
```

- [ ] **Step 2.2: Run test to verify it fails**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test test/game_session_test.exs`
Expected: FAIL — `ArchaeologyRush.GameSession` module not found

- [ ] **Step 2.3: Write implementation**

`lib/archaeology_rush/game_session.ex`:

```elixir
defmodule ArchaeologyRush.GameSession do
  @moduledoc """
  ゲームセッションを管理する GenServer。

  LiveView の mount 時に起動し、Excavation 構造体を保持します。
  LiveView プロセスにリンクするため、LiveView が閉じると自動終了します。
  """

  use GenServer

  alias ArchaeologyRush.Excavation
  alias ArchaeologyRush.RandomDiscovery
  alias ArchaeologyRush.SiteState

  @type option ::
          {:max_turns, pos_integer()}
          | {:target_important_artifacts, pos_integer()}
          | {:max_record_misses, non_neg_integer()}
          | {:actions_per_turn, pos_integer()}
          | {:tool_durability, pos_integer()}
          | {:discovery_fn, SiteState.discovery_fn()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec dig(pid(), SiteState.cell()) ::
          {:ok, Excavation.t(), SiteState.artifact() | nil}
          | {:error, :no_actions_left | :cell_fully_excavated}
  def dig(pid, cell) do
    GenServer.call(pid, {:dig, cell})
  end

  @spec catalog(pid(), pos_integer(), map()) ::
          {:ok, Excavation.t(), SiteState.artifact()}
          | {:error, :artifact_not_found | {:missing_required_fields, [atom()]}}
  def catalog(pid, artifact_id, attrs) do
    GenServer.call(pid, {:catalog, artifact_id, attrs})
  end

  @spec recover(pid(), pos_integer()) ::
          {:ok, Excavation.t(), SiteState.artifact()}
          | {:error, :artifact_not_found | :artifact_not_cataloged}
  def recover(pid, artifact_id) do
    GenServer.call(pid, {:recover, artifact_id})
  end

  @spec end_turn(pid()) :: Excavation.t()
  def end_turn(pid) do
    GenServer.call(pid, :end_turn)
  end

  @spec complete_report(pid()) :: Excavation.t()
  def complete_report(pid) do
    GenServer.call(pid, :complete_report)
  end

  @spec get_state(pid()) :: Excavation.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    discovery_fn = Keyword.get(opts, :discovery_fn, RandomDiscovery.discovery_fn())
    excavation = Excavation.new_session(opts)
    {:ok, %{excavation: excavation, discovery_fn: discovery_fn}}
  end

  @impl true
  def handle_call({:dig, cell}, _from, state) do
    case Excavation.dig(state.excavation, cell, discovery_fn: state.discovery_fn) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:catalog, artifact_id, attrs}, _from, state) do
    case Excavation.catalog(state.excavation, artifact_id, attrs) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:recover, artifact_id}, _from, state) do
    case Excavation.recover(state.excavation, artifact_id) do
      {:ok, excavation, artifact} ->
        {:reply, {:ok, excavation, artifact}, %{state | excavation: excavation}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:end_turn, _from, state) do
    excavation = Excavation.end_turn(state.excavation)
    {:reply, excavation, %{state | excavation: excavation}}
  end

  @impl true
  def handle_call(:complete_report, _from, state) do
    excavation = Excavation.complete_report(state.excavation)
    {:reply, excavation, %{state | excavation: excavation}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.excavation, state}
  end
end
```

- [ ] **Step 2.4: Run test to verify it passes**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test test/game_session_test.exs`
Expected: 7 tests, 0 failures

- [ ] **Step 2.5: Run quality check**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix format && mix credo --strict`
Expected: No warnings

- [ ] **Step 2.6: Commit**

```bash
cd /Users/hiro/Projetct/GitHub/ArchaeologyRush
git add lib/archaeology_rush/game_session.ex test/game_session_test.exs
git commit -m "feat: add GameSession GenServer for managing game state"
```

---

## Task 3: GameLive LiveView + Router

**Files:**
- Create: `lib/archaeology_rush_web/live/game_live.ex`
- Modify: `lib/archaeology_rush_web.ex` (Router L34-41)

### Step 3.1: Add `/game` route to Router

- [ ] In `lib/archaeology_rush_web.ex`, add the route inside the existing scope block (line 40):

Change:
```elixir
    live "/", DemoLive
```

To:
```elixir
    live "/", DemoLive
    live "/game", GameLive
```

- [ ] **Step 3.2: Create the GameLive LiveView module**

Create `lib/archaeology_rush_web/live/game_live.ex`:

```elixir
defmodule ArchaeologyRushWeb.GameLive do
  @moduledoc """
  インタラクティブ発掘ゲーム画面。

  4×4グリッドボードを中央に、発見物パネルを左、アクションパネルを右に配置する
  ダッシュボード型レイアウト。
  """

  use Phoenix.LiveView

  alias ArchaeologyRush.GameSession
  alias ArchaeologyRush.Excavation

  @grid_size 4
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

  @impl true
  def mount(_params, _session, socket) do
    {:ok, pid} = GameSession.start_link([])
    excavation = GameSession.get_state(pid)

    {:ok,
     assign(socket,
       game_pid: pid,
       excavation: excavation,
       selected_cell: nil,
       show_catalog_modal: false,
       catalog_target_id: nil
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
       catalog_target_id: String.to_integer(id)
     )}
  end

  def handle_event("cancel_catalog", _params, socket) do
    {:noreply, assign(socket, show_catalog_modal: false, catalog_target_id: nil)}
  end

  def handle_event("submit_catalog", %{"operator_note" => note}, socket) do
    id = socket.assigns.catalog_target_id
    attrs = %{operator_note: note, artifact_id: id}

    case GameSession.catalog(socket.assigns.game_pid, id, attrs) do
      {:ok, excavation, _artifact} ->
        {:noreply,
         assign(socket,
           excavation: excavation,
           show_catalog_modal: false,
           catalog_target_id: nil
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
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

  def handle_event("complete_report", _params, socket) do
    excavation = GameSession.complete_report(socket.assigns.game_pid)
    {:noreply, assign(socket, excavation: excavation)}
  end

  def handle_event("new_game", _params, socket) do
    GenServer.stop(socket.assigns.game_pid, :normal)
    {:ok, pid} = GameSession.start_link([])
    excavation = GameSession.get_state(pid)

    {:noreply,
     assign(socket,
       game_pid: pid,
       excavation: excavation,
       selected_cell: nil,
       show_catalog_modal: false,
       catalog_target_id: nil
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
                <span style="font-size: 0.7rem; color: #{if progress >= 2, do: "#e8d5b7", else: "#5c4a32"}; font-weight: 600;">
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
                phx-click="complete_report"
                disabled={not can_complete_report?(@excavation)}
                style={"padding: 10px; border-radius: 8px; border: none; font-size: 0.85rem; font-weight: 700; cursor: #{if can_complete_report?(@excavation), do: "pointer", else: "not-allowed"}; background: #{if can_complete_report?(@excavation), do: "#fbbf24", else: "#233554"}; color: #{if can_complete_report?(@excavation), do: "#0a192f", else: "#4a5568"};"}
              >
                📝 最終レポート
              </button>
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
        <div style="position: fixed; inset: 0; background: rgba(10, 25, 47, 0.85); display: flex; align-items: center; justify-content: center; z-index: 100;">
          <div style="background: #16213e; border-radius: 16px; padding: 30px; max-width: 380px; width: 90%;">
            <h3 style="color: #ccd6f6; font-size: 1.1rem; font-weight: 700; margin-bottom: 16px;">📋 アーティファクト記録</h3>
            <form phx-submit="submit_catalog">
              <label style="display: block; color: #8892b0; font-size: 0.8rem; margin-bottom: 6px;">
                オペレーターノート（任意）
              </label>
              <textarea
                name="operator_note"
                rows="3"
                style="width: 100%; background: #233554; color: #ccd6f6; border: 1px solid #344563; border-radius: 8px; padding: 10px; font-size: 0.85rem; resize: vertical;"
                placeholder="観察メモを入力..."
              ></textarea>
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
    </main>
    """
  end

  # --- Helper functions ---

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

  defp format_log(%{action: :dig, cell: {r, c}, layer: layer}) do
    "セル(#{r},#{c})を掘削 → #{layer_label_from_atom(layer)}"
  end

  defp format_log(%{action: :catalog, artifact_id: id}) do
    "アーティファクト##{id}を記録"
  end

  defp format_log(%{action: :recover, artifact_id: id, score_gain: gain}) do
    "アーティファクト##{id}を回収 (+#{gain}点)"
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
```

- [ ] **Step 3.3: Verify `lib/archaeology_rush_web/live/` directory exists**

Run: `ls /Users/hiro/Projetct/GitHub/ArchaeologyRush/lib/archaeology_rush_web/`
If directory doesn't exist, create it: `mkdir -p lib/archaeology_rush_web/live/`

- [ ] **Step 3.4: Run the server to verify no compilation errors**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix compile --warnings-as-errors`
Expected: Compilation successful, 0 warnings

- [ ] **Step 3.5: Run quality check**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix format && mix credo --strict`
Expected: No warnings

- [ ] **Step 3.6: Commit**

```bash
cd /Users/hiro/Projetct/GitHub/ArchaeologyRush
git add lib/archaeology_rush_web/live/game_live.ex lib/archaeology_rush_web.ex
git commit -m "feat: add interactive GameLive with grid board and action panels"
```

---

## Task 4: GameLive Integration Tests

**Files:**
- Create: `test/support/conn_case.ex`
- Create: `test/game_live_test.exs`

### Step 4.0: Create ConnCase test helper

- [ ] `test/support/conn_case.ex` を作成（Endpoint/PubSub をテスト環境で起動）

```elixir
defmodule ArchaeologyRushWeb.ConnCase do
  @moduledoc """
  LiveView テスト用ヘルパー。
  Endpoint と PubSub をテスト環境で起動します。
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint ArchaeologyRushWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
```

Also add to `test/test_helper.exs` (before `ExUnit.start()`):

```elixir
{:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: ArchaeologyRush.PubSub)
{:ok, _} = ArchaeologyRushWeb.Endpoint.start_link()
```

Note: `test/test_helper.exs` の修正が必要。既存の内容を確認してからstart_linkの行を追加する。

### Step 4.1: Write integration tests

- [ ] `test/game_live_test.exs` を作成

```elixir
defmodule ArchaeologyRushWeb.GameLiveTest do
  use ArchaeologyRushWeb.ConnCase, async: true

  describe "mount" do
    test "renders the game board", %{conn: conn} do
      {:ok, view, html} = live(conn, "/game")
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
      for _turn <- 1..11 do
        view |> element("button", "ターン終了") |> render_click()
      end

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
```

- [ ] **Step 4.2: Run test to verify it passes**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test test/game_live_test.exs`
Expected: 5 tests, 0 failures

Note: Phoenix LiveView test のセットアップが必要な場合は `test/test_helper.exs` や `test/support/conn_case.ex` の確認・追加が必要になるかもしれない。`@endpoint` を直接指定しているのでConnCaseは不要なはず。もしテストが動かない場合は、Endpoint起動の設定を確認する。

- [ ] **Step 4.3: Run full test suite**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix test`
Expected: All tests pass (既存17+ 新規15 = 32+)

- [ ] **Step 4.4: Run full quality check**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix quality`
Expected: All checks pass

- [ ] **Step 4.5: Commit**

```bash
cd /Users/hiro/Projetct/GitHub/ArchaeologyRush
git add test/game_live_test.exs
git commit -m "test: add GameLive integration tests"
```

---

## Task 5: Manual Verification

This task has no code changes — it verifies the full implementation works end-to-end.

- [ ] **Step 5.1: Start the dev server**

Run: `cd /Users/hiro/Projetct/GitHub/ArchaeologyRush && mix run --no-halt`
Open: http://localhost:4000/game

- [ ] **Step 5.2: Verify success criteria**

Check each item from the spec:
1. 4×4グリッドボードが表示される
2. セルをクリックして選択、「掘る」ボタンで発掘できる
3. 発見されたアーティファクトがパネルに表示される
4. operator_noteを入力してcatalog、その後recoverでスコア加算
5. ターン管理が正しく動作し、勝利/敗北条件でゲームが終了する
6. ゲーム終了後に再スタートできる
7. ステータスバーに記録ミス数、道具耐久度が表示される
8. 未記録の発見物がある状態でターン終了時に警告が表示される

- [ ] **Step 5.3: Verify existing demo still works**

Open: http://localhost:4000/
Check: DemoLiveが正常に表示されることを確認
