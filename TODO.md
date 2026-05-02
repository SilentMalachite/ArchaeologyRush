# ArchaeologyRush TODO

最終確認日: 2026-05-02

## 現状サマリ

- [x] `SiteState` / `Excavation` / `GameSession` / `RandomDiscovery` / `GameLive` は実装済み
- [x] `/game` で 4x4 グリッドのインタラクティブ UI が動作する
- [x] `/` でシナリオデモを確認できる
- [x] `mix test` 通過 (`45 tests, 0 failures`)
- [x] `mix quality` 通過
- [x] DB 永続化の保存/読込 API は実装済み
- [ ] DB 永続化は `GameSession` / `/game` のゲーム進行に未接続
- [x] 仕様書と現行実装のズレを P0 範囲で同期済み

## 優先 TODO

### P0: ドキュメントと現行実装の同期

- [x] `docs/specification.md` の「実装済み範囲」「受け入れ条件」「未決事項」を、現在の `/game` 実装に合わせて更新する
- [x] 仕様書内の「LiveView 最小画面でデモ出力を表示可能」中心の記述を、インタラクティブ UI 実装後の状態へ更新する
- [x] README / 仕様書 / TODO の役割分担を整理し、状態管理の二重化を減らす

### P1: 永続化の土台を作る

- [x] 実行時の `%Excavation{}` / `%SiteState{}` に対応する保存モデルを設計する
- [x] `Artifact` スキーマを、現在のゲーム内 artifact 情報 (`kind`, `quality`, `status`, `coordinate`, `depth`, `layer_id`, `discovered_turn`, `operator_note`) に合わせて見直す
- [x] 発掘セッション保存と `TurnLog` 永続化を追加し、行動履歴を Repo に記録できるようにする
- [x] セーブ / ロードのユースケース API と ExUnit テストを追加する

### P1: UI とユースケースの仕上げ

- [x] `complete_report` のワンクリック完了を、実際の入力フォームと検証に置き換える
- [x] Catalog UI を、必須項目の確認・不足表示・再入力まで見える形にする
- [x] 混入ペナルティ、記録ミス、スコア変動理由を UI 上で追いやすくする
- [x] `GameLive` の統合テストを catalog / recover / complete_report / game over 分岐まで広げる

### P2: 仮実装の置き換え

- [x] `RandomDiscovery` の層固定の仮確率ロジックを、セル×層の確率テーブルを参照する実装へ置き換える
- [x] 発見確率テーブルの詳細値を、確定済みのユーザー仕様に沿って反映する
- [x] 重要遺物判定や評価ロジックの仮置き部分を、ユーザー仕様に沿って再確認する
- [x] 道具耐久や層混入の扱いで、現在は UI や終了判定に十分反映していない箇所を洗い出して実装へ反映する

### P2: 品質ゲートと運用整備

- [x] `mix quality` に `mix credo` と `mix dialyzer` をどう組み込むか決め、日常的に回せる品質ゲートへ揃える
- [x] Elixir Desktop の配布ターゲットとビルド手順を決める
- [x] セーブデータ形式と移行方針を決める

## ユーザー仕様の確認が必要な項目

- [x] 最終レポートの必須入力項目
- [x] 発見確率テーブルの詳細条件 (層、座標、ターン、補正要素)
- [x] 重要遺物の定義と評価点
- [x] 道具耐久が 0 になった後の扱い
