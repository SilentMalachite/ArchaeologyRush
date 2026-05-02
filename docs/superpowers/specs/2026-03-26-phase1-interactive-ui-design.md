# Phase 1: Interactive UI Design

## Overview

ArchaeologyRushの読み取り専用デモUIを、プレイ可能なインタラクティブゲームUIに進化させる。
既存のコアエンジン（SiteState / Excavation）は変更せず、LiveViewとGenServerで操作可能なゲーム画面を構築する。

## Design Decisions

| 判断項目 | 決定 | 理由 |
|---------|------|------|
| UIスコープ | グリッドボード付き（B） | 遊べるレベルかつスコープ管理可能 |
| レイアウト | ボード中央＋左右パネル（C） | 全情報を一画面に集約するダッシュボード型 |
| グリッドサイズ | 4×4（16セル） | バランスの良い複雑さ |
| 発見ロジック | ランダム生成（A） | プロトタイプ用仮実装。後からドメイン仕様に差し替え可能 |
| catalog入力 | context_type + operator_note | 出土状況/コンテキストと記録メモを必須記録として扱う |
| 座標系 | 0-indexed {0,0}..{3,3} | Enum.with_indexとの親和性 |

## Architecture

```
+---------------------------------------------------+
|              GameLive (LiveView)                   |
|  +----------+--------------+----------+           |
|  | 発見物   |  4x4 グリッド | アクション|           |
|  | パネル   |   (ボード)   | パネル   |           |
|  +----------+--------------+----------+           |
|  +------------------------------------------+     |
|  |           ログパネル                      |     |
|  +------------------------------------------+     |
+---------------------------------------------------+
        |                          ^
        | handle_event             | assign更新
        v                          |
+---------------------------------------------------+
|           GameSession (GenServer)                  |
|  - Excavation構造体を保持                          |
|  - discovery_fn にランダム生成を注入               |
|  - 全操作を委譲 -> 新state返却                     |
+---------------------------------------------------+
        |
        v
+---------------------------------------------------+
|     Excavation -> SiteState (既存・変更なし)       |
+---------------------------------------------------+
```

### Components

#### 1. GameSession (GenServer)

ゲーム状態をプロセスで管理する。LiveViewのmount時に起動し、LiveViewプロセスにリンクする（LiveViewが閉じたらGameSessionも終了）。

**責務:**
- Excavation構造体の保持と操作委譲
- discovery_fnコールバックの注入（デフォルト: RandomDiscovery）
- 状態のスナップショット返却

**API:**
- `start_link(opts)` — 新規ゲームセッション開始
- `dig(pid, cell)` — セルを掘る
- `catalog(pid, artifact_id, attrs)` — アーティファクトを記録
- `recover(pid, artifact_id)` — アーティファクトを回収
- `end_turn(pid)` — ターン終了
- `get_state(pid)` — 現在の状態取得
- `complete_report(pid)` — 最終レポート完了

#### 2. RandomDiscovery

ランダムアーティファクト発見ロジック。`discovery_fn` の型 `(cell, layer, dig_count -> discovery_result)` に準拠。

**ロジック:**
- 層が深いほど発見確率が上がる（upper: 20%, middle: 40%, lower: 60%）
- アーティファクト種類: pottery_shard, stone_tool, bone_fragment, feature_mark をランダム選択
- 品質: poor/fair/good/excellent を重み付きランダム選択

#### 3. GameLive (LiveView)

インタラクティブゲーム画面。

**assigns:**
- `game_pid` — GameSessionプロセスPID
- `excavation` — Excavation構造体（表示用スナップショット）
- `selected_cell` — 現在選択中のセル `{row, col}` or nil
- `show_catalog_modal` — catalogモーダル表示フラグ
- `catalog_target_id` — 記録対象のartifact_id
- `catalog_values` — context_type / operator_note の入力保持
- `catalog_errors` — catalog入力エラー

注: `game_over` は持たない。`Excavation.game_status/1` から導出する（`:in_progress` 以外がゲーム終了）。

**イベントハンドラ:**
- `select_cell` — セル選択
- `dig` — 選択セルを掘る
- `open_catalog` — 記録対象を選んでモーダル表示
- `submit_catalog` — context_typeとoperator_note入力後に記録実行
- `cancel_catalog` — モーダルキャンセル
- `recover` — アーティファクト回収
- `end_turn` — ターン終了
- `complete_report` — 最終レポート（勝利条件チェック）
- `new_game` — 新規ゲーム開始

**レンダリング:**
- ステータスバー（上部）: ターン数/最大ターン、残りアクション、スコア、記録ミス数(current/max)、道具耐久度、ゲーム状態バッジ
- 発見物パネル（左）: アーティファクトリスト（種類アイコン、品質、ステータスチップ）。各アーティファクトにcatalog/recoverボタン。ステータス: discovered(黄)=記録可能、on_hold(橙)=記録可能(前ターンの未記録品)、cataloged(青)=回収可能、recovered(緑)=完了
- グリッドボード（中央）: 4×4グリッド。セルは層の深さに応じた色分け。選択セルはハイライト。発見済みアーティファクトはアイコン表示
- アクションパネル（右）: dig/end_turn/complete_reportボタン。状況に応じて有効/無効制御
- ログパネル（下部）: turn_logsの直近エントリを表示
- ゲーム終了オーバーレイ: 勝利/敗北メッセージ + 再スタートボタン

**ボタン有効/無効ルール:**
- 掘る: selected_cell != nil かつ actions_left > 0
- 記録/回収: 該当ステータスのアーティファクトが存在する場合のみ
- ターン終了: 常に有効。ただし :discovered アーティファクトが存在する場合は警告表示（record_missが発生する）
- 最終レポート: 回収済み重要アーティファクト >= target の場合のみ

## Grid Cell Visualization

各セルの表示:
- 未掘削: 薄い土色（上層デフォルト）
- cell_progress に応じた色: 上層=#e8d5b7, 中層=#c4a876, 下層=#8b7355
- 選択中: ボーダーハイライト（#64ffda）
- アーティファクト発見済み: 種類に応じたアイコン（pottery_shard=陶器, stone_tool=石, bone_fragment=骨, feature_mark=遺構マーク）

## User Interaction Flow

```
[セルクリック] -> selected_cell更新 + ハイライト表示
     |
[掘るボタン] -> GameSession.dig(cell)
     |          -> OK: グリッド更新 + アーティファクト発見通知
     |          -> Error: エラーメッセージ表示
     |
[発見物の記録ボタン] -> catalogモーダル表示（context_type + operator_note入力）
     |                -> 送信 -> GameSession.catalog(id, attrs)
     |                -> context_typeは固定選択肢 feature_inside（遺構内）
     |                -> layer_idは発見時の層情報を利用
     |
[発見物の回収ボタン] -> GameSession.recover(id) -> スコア更新
     |
[ターン終了] -> GameSession.end_turn() -> ターン進行
     |
[ゲーム状態チェック] -> game_status判定
     |                -> :in_progress -> 続行
     |                -> :won -> 勝利オーバーレイ
     |                -> {:lost, reason} -> 敗北オーバーレイ
```

## File Structure (New/Modified)

### New Files
- `lib/archaeology_rush/game_session.ex` — GenServer
- `lib/archaeology_rush/random_discovery.ex` — ランダム発見ロジック
- `lib/archaeology_rush_web/live/game_live.ex` — LiveView

### Modified Files
- `lib/archaeology_rush_web.ex` — Router に `/game` ルート追加、GameLive関連を分離

### Test Files
- `test/game_session_test.exs` — GameSession単体テスト
- `test/random_discovery_test.exs` — 発見ロジックテスト
- `test/game_live_test.exs` — LiveView統合テスト

## Error Handling

- GameSession GenServer呼び出しが失敗した場合（タイムアウト、クラッシュ）、LiveViewはflashメッセージでエラーを表示し、クラッシュしない
- 不正な操作（actions_left=0で掘る等）はExcavation/SiteStateのエラー返却をそのままUIに表示

## Implementation Chunks (max 3 files each)

CLAUDE.mdの「1回の変更で最大3ファイル」ルールに従い、以下の順序で実装する:

1. **Chunk 1**: RandomDiscovery + テスト（2ファイル）
   - `lib/archaeology_rush/random_discovery.ex`
   - `test/random_discovery_test.exs`

2. **Chunk 2**: GameSession + テスト（2ファイル）
   - `lib/archaeology_rush/game_session.ex`
   - `test/game_session_test.exs`

3. **Chunk 3**: GameLive + Router変更（2ファイル）
   - `lib/archaeology_rush_web/live/game_live.ex`
   - `lib/archaeology_rush_web.ex`（Router変更のみ）

4. **Chunk 4**: GameLiveテスト + 統合確認（1ファイル）
   - `test/game_live_test.exs`

## Impact on Existing Code

- **SiteState**: 変更なし
- **Excavation**: 変更なし
- **Demo / DemoLive**: 変更なし（`/` ルート維持）
- **Router**: `/game` ルート追加のみ

## Success Criteria

1. ブラウザで `/game` にアクセスすると4×4のグリッドボードが表示される
2. セルをクリックして選択、「掘る」ボタンで発掘できる
3. 発見されたアーティファクトがパネルに表示される
4. 出土状況/コンテキストとoperator_noteを入力してcatalog、その後recoverでスコア加算
5. ターン管理が正しく動作し、勝利/敗北条件でゲームが終了する
6. ゲーム終了後に再スタートできる
7. 全テストがパスし、mix quality が通る
