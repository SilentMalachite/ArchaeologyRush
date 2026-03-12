# ArchaeologyRush

Elixir / Phoenix LiveView / Elixir Desktop を前提にした考古学発掘シミュレーションの初期スキャフォールドです。

現時点では `AGENT.md` の制約に従い、考古学ドメインの仕様実装は行わず、土台だけを分割可能な形で配置しています。

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
├── priv/
│   ├── repo/
│   └── static/
├── src/
└── test/
    └── support/
```

## Scope of This Step

* `mix.exs` に Phoenix / LiveView / Desktop / SQLite / vix / QA 系依存の初期定義を追加
* `elixirc_paths/1` と `quality` alias を定義
* 今後の Phoenix アプリ本体、監督ツリー、ExUnit 基盤を追加できるディレクトリを先行作成

## Planned Next Chunks

1. `config/` と `lib/` のアプリケーション骨格を追加
2. `test/` に ExUnit 基盤と最初の回帰防止テストを追加
3. Phoenix LiveView と Desktop エントリポイントを接続

## Domain Boundary

考古学的な用語体系、発掘工程、層位学ルール、遺物分類は未実装です。これらは `AGENT.md` の指示どおり、ユーザー仕様の確認後にのみ追加します。
