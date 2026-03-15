# ArchaeologyRush

Elixir / Phoenix LiveView / Elixir Desktop を前提にした考古学発掘シミュレーションです。

現時点では、コア状態遷移、ユースケース層、終了判定、デモスクリプト、最小 LiveView 画面まで実装済みです。

## Current Layout

```text
ArchaeologyRush/
├── AGENT.md
├── README.md
├── mix.exs
├── .formatter.exs
├── assets/
├── config/
├── docs/
├── lib/
│   └── archaeology_rush/
│   └── archaeology_rush_web.ex
├── priv/
│   ├── repo/
│   └── static/
├── scripts/
├── src/
└── test/
    └── support/
```

## Current Status

* `SiteState` に `dig` / `catalog` / `recover` / `end_turn` を実装
* `Excavation` にユースケース API と `game_status/1` を実装
* `Demo.run/0` と `scripts/demo_excavation.exs` で進行中 / 勝利 / 敗北の流れを確認可能
* `http://localhost:4000` に最小 LiveView 画面を追加
* `mix test` と `mix quality` は通過済み

## Run

```bash
mix test
mix quality

# CLI demo
mix run scripts/demo_excavation.exs

# LiveView demo
mix run --no-halt
```

LiveView demo は `http://localhost:4000` で確認できます。

## Implemented Scope

* コア状態遷移: 行動消費、層進行、遺物発見、記録、回収、ターン終了
* 終了判定: `:in_progress` / `:won` / `{:lost, reason}`
* デモ表示: progression / winning / losing case
* Web 表示: LiveView でデモ出力をブラウザ表示

## Domain Boundary

考古学ドメインはユーザー確定仕様に従って実装を進めています。今後の詳細ルール追加も、引き続きユーザー仕様を基準に進めます。
