# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# kawaz/timespec — CLI時間指定パーサ

## 概要

MoonBit 製の CLI `--since` / `--until` 向け時間指定パーサライブラリ。

## ビルド・テスト

just を使用。`justfile` 参照（canonical: kawaz/bump-semver / kawaz/kuu.mbt 系）。

- `just` — lint + test（デフォルト）
- `just lint` — fmt-check + check（型チェック、警告エラー扱い）
- `just fmt` — フォーマット自動修正
- `just fmt-check` — フォーマット検査のみ
- `just check` — 型チェック（`moon check --deny-warn`）
- `just test` — テスト実行（native ターゲット）
- `just test-all` — 全ターゲットでテスト実行
- `just test-update` — スナップショット更新
- `just bump-version [patch|minor|major]` — VERSION / moon.mod の version を進める
- `just push` — gate 群を通過してから push（`bump-semver vcs push`）
- `moon test -f "test name"` — 単一テスト実行（部分一致）
- `moon test --target native` — ターゲット別テスト（native / js / wasm / wasm-gc / all）

## プロジェクト構造

```
README.md, README-ja.md  # ユーザ向け窓口（英語版が canonical、ja は翻訳ペア）
VERSION                  # semver 文字列、moon.mod の version と同期
src/                     # メイン実装
docs/
  DESIGN.md, DESIGN-ja.md  # 総合設計書（ja が canonical）
  decisions/               # 設計判断記録（DR-NNNN-...）
    INDEX.md
```

## 設計資料

- `docs/DESIGN-ja.md` / `docs/DESIGN.md` — 型設計、API、パース規則
- `docs/decisions/INDEX.md` — DR 一覧
- `docs/decisions/` — 設計判断の経緯（DR-0003〜DR-0009）

## アーキテクチャ

4つのパース関数が階層的に構成される:

- `parse_duration` — `5m`, `1.5h`, `3_600_000ms` → Duration
- `parse_timespec` — duration + datetime の複合入力をマルチパス方式（6フェーズ）でパース → TimeSpec（Absolute/Relative）
- `parse_range` — `since`/`until` 2引数方式 or `input` にチルダ(`~`)区切り文字列 → TimeRange（Mixed時アンカー解決）
- `parse_tz_offset` — `+09:00`, `9h` → TzOffset

主要な型:
- `Duration`: `struct Duration(Int64)` — ms 精度の期間（newtype）。定数 `millisecond`〜`week`、演算子 `+`, `-`, `neg`, `scale`
- `EpochTime`: `struct EpochTime(Int64)` — epoch からの経過 ms（newtype）。`add_duration` で Duration 加算
- `TimeSpec`: `Absolute(EpochTime, Duration) | Relative(EpochTime, Duration)` — 再シリアライズで意図を保存
- `TimeRange`: `{ since: TimeSpec?, until: TimeSpec? }`

## コーディング規約

- MoonBit 標準スタイル（`///|` ブロックセパレータ）
- テスト: `_test.mbt`（ブラックボックス）、`_wbtest.mbt`（ホワイトボックス）
- スナップショットテスト: `inspect!(val, content="...")`
- エラー: `suberror` + `raise`
- TDD で開発
