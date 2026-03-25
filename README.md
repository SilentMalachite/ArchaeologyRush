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
* `RandomDiscovery` でアーティファクトをランダム生成（仮実装・差し替え可能）
* `http://localhost:4000/game` に **4×4グリッドのインタラクティブゲーム画面**を追加
* `http://localhost:4000` に読み取り専用デモ画面（progression / winning / losing シナリオ）
* `mix test` (37テスト) と `mix quality` は通過済み

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
* インタラクティブUI: セル選択・掘削・記録モーダル・回収・ターン管理・ゲームオーバー表示
* デモ表示: progression / winning / losing case をカードで可視化
* DB インフラ: Ecto + SQLite3、artifacts テーブル（ゲームロジックとは未連携）

## Domain Boundary

考古学ドメインはユーザー確定仕様に従って実装を進めています。今後の詳細ルール追加も、引き続きユーザー仕様を基準に進めます。
