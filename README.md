# ArchaeologyRush

Elixir / Phoenix LiveView / Elixir Desktop を前提にした考古学発掘シミュレーションです。

## Current Layout

```text
ArchaeologyRush/
├── CLAUDE.md / AGENTS.md
├── README.md
├── mix.exs
├── config/
├── docs/
│   └── superpowers/
│       ├── specs/   # 設計仕様書
│       └── plans/   # 実装計画書
├── lib/
│   ├── archaeology_rush/
│   │   ├── site_state.ex        # コア状態機械
│   │   ├── excavation.ex        # ユースケース API
│   │   ├── game_session.ex      # GenServer (セッション管理)
│   │   ├── random_discovery.ex  # ランダム遺物発見ロジック
│   │   ├── demo.ex              # CLIデモ出力
│   │   ├── artifact.ex          # Ectoスキーマ
│   │   └── repo.ex
│   └── archaeology_rush_web.ex        # Endpoint / Router / DemoLive
│   └── archaeology_rush_web/
│       └── live/
│           └── game_live.ex     # インタラクティブゲーム画面
├── priv/repo/migrations/
├── scripts/
└── test/
    ├── support/
    │   ├── repo_case.ex
    │   └── conn_case.ex         # LiveViewテストヘルパー
    └── *_test.exs
```

## Current Status

* `SiteState` に `dig` / `catalog` / `recover` / `end_turn` を実装
* `Excavation` にユースケース API と `game_status/1` を実装
* `GameSession` GenServer でゲーム状態をプロセス管理
* `RandomDiscovery` でセル×層の確率テーブルに基づくアーティファクト発見を実行
* `http://localhost:4000/game` に **4×4グリッドのインタラクティブゲーム画面**を追加
* `http://localhost:4000` に読み取り専用デモ画面（progression / winning / losing シナリオ）
* `mix test` (47テスト) と `mix quality` は通過済み
* DB 永続化の保存/読込 API は実装済み（`GameSession` / `/game` の進行には未接続）

## Run

```bash
mix setup     # 依存インストール + DB作成

mix test      # テスト実行
mix quality   # format + compile strict + test

# CLI demo
mix run scripts/demo_excavation.exs

# LiveView (ゲーム + デモ)
mix run --no-halt
```

| URL | 内容 |
|-----|------|
| `http://localhost:4000/game` | インタラクティブゲーム画面 |
| `http://localhost:4000` | 読み取り専用デモ画面 |

## Implemented Scope

* コア状態遷移: 行動消費、層進行、遺物発見、記録（catalog）、回収（recover）、ターン終了
* 終了判定: `:in_progress` / `:won` / `{:lost, :turn_limit_reached | :too_many_record_misses}`
* インタラクティブUI: セル選択・掘削・記録モーダル・回収・ターン管理・最終レポートフォーム・ゲームオーバー表示
* プレイフィードバック: Catalog必須項目検証、出土状況/コンテキスト記録、層混入ペナルティ、記録ミス、スコア増減理由を画面ログで表示
* デモ表示: progression / winning / losing case をカードで可視化
* DB インフラ: Ecto + SQLite3、game_sessions / artifacts / turn_logs による保存/読込 API
* 発見ロジック: `RandomDiscovery.discovery_fn/1` で確率テーブル、種類重み、品質重みを注入可能

## Documentation Roles

* `README.md`: 現在の起動方法、主要構成、実装済み範囲の入口
* `docs/specification.md`: ユーザー確定仕様、現行実装との対応、受け入れ条件、未決事項
* `TODO.md`: 次に着手する作業順序と、仕様確認が必要な項目の短い一覧

## Domain Boundary

考古学ドメインはユーザー確定仕様に従って実装を進めています。今後の詳細ルール追加も、引き続きユーザー仕様を基準に進めます。
