# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# kawaz/timespec — CLI時間指定パーサ

## 概要

MoonBit 製の CLI `--since` / `--until` 向け時間指定パーサライブラリ。

## ビルド・テスト

just を使用。`justfile` 参照。

- `just` — check + test（デフォルト）
- `just fmt` — フォーマット
- `just check` — 型チェック（警告エラー扱い）
- `just test` — テスト実行
- `just test-update` — スナップショット更新
- `moon test -f "test name"` — 単一テスト実行（部分一致）

## プロジェクト構造

```
src/              # メイン実装
docs/
  DESIGN.md       # 総合設計書
  decision-records/  # 設計判断記録（DR）
```

## 設計資料

- `docs/DESIGN.md` — 型設計、API、パース規則
- `docs/decision-records/` — 設計判断の経緯

## アーキテクチャ

4つのパース関数が階層的に構成される:

- `parse_duration` — `5m`, `1.5h`, `3_600_000ms` → Duration
- `parse_timespec` — duration + datetime の複合入力 → TimeSpec（Absolute/Relative）
- `parse_range` — `since~until` 形式 → TimeRange（アンカー解決含む）
- `parse_tz_offset` — `+09:00`, `9h` → TzOffset

主要な型:
- `Duration`: `Ms(Int64) | MsNs(Int64, Int)` — ms精度 or ms+sub-ms-ns精度
- `TimeSpec`: `Absolute(Int64) | Relative(Int64, Duration)` — 再シリアライズで意図を保存
- `TimeRange`: `{ since: TimeSpec?, until: TimeSpec? }`

## コーディング規約

- MoonBit 標準スタイル（`///|` ブロックセパレータ）
- テスト: `_test.mbt`（ブラックボックス）、`_wbtest.mbt`（ホワイトボックス）
- スナップショットテスト: `inspect!(val, content="...")`
- エラー: `suberror` + `raise`
- TDD で開発
