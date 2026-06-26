# kawaz/timespec

> [English](./README.md) | 日本語

MoonBit 向けの CLI 用時間指定パーサ。

`5m`、`@1h30m`、`2026-03-15T12:00:00Z+5h`、`3 minutes ago` のような柔軟な時間表現を構造化された `TimeSpec` 値にパースし、`--since` / `--until` スタイルの CLI オプションで使えます。

## インストール

```
moon add kawaz/timespec
```

## クイックスタート

```moonbit
// Duration parsing
let d = @timespec.parse_duration("1h30m")  // Duration(5400000)

// TimeSpec parsing (relative)
let ts = @timespec.parse_timespec("5m", default_sign=Minus)
// Relative(EpochTime(now - 300000), Duration(-300000))

// TimeSpec parsing (absolute with @)
let ts = @timespec.parse_timespec("@5m", default_sign=Minus)
// Absolute(EpochTime(now - 300000), Duration(-300000))

// Time range
let r = @timespec.parse_range(since="5m", until="3m", default_sign=Minus)
// { since: Some(Relative(...)), until: Some(Relative(...)) }

// Re-serialization
ts.to_cli_string()
// Relative → "+5m" / Absolute → "2026-03-15T12:00:00Z"
```

## サポートする表現

### Duration (`parse_duration`)

| 入力 | パース結果 |
|-------|-----------|
| `5m` | 5 分 |
| `1h30m` | 1 時間 30 分 |
| `1.5h` | 1.5 時間（= 90 分） |
| `500ms` | 500 ミリ秒 |
| `3_600_000ms` | アンダースコア区切り |
| `2d12h` | 2 日 12 時間 |
| `5 minutes ago` | -5 分（`ago` は符号を反転） |
| `+1h -30m` | 1 時間 - 30 分（= 30 分） |

**単位**: `w`/`week(s)`, `d`/`day(s)`, `h`/`hour(s)`, `m`/`min`/`minute(s)`, `s`/`sec`/`second(s)`, `ms`/`millisecond(s)`

### TimeSpec (`parse_timespec`)

`@` マーカーは時間表現を **Absolute**（再シリアライズで ISO 8601 形式になる）として固定します。`@` がない場合、duration のみの入力は **Relative**（再シリアライズで `+5m` のような符号付き duration になる）として扱われます。

`default_sign=Minus` での例:

| 入力 | 種別 | 説明 |
|-------|------|-------------|
| `5m` | Relative | 現在から 5 分前 |
| `+5m` | Relative | 現在から 5 分後 |
| `@5m` | Absolute | 5 分前を固定 |
| `-5h@` | Absolute | `@` の位置は柔軟 |
| `2026-03-15T12:00:00Z` | Absolute | ISO 8601 日時 |
| `2026-03-15T21:00:00+09:00` | Absolute | タイムゾーンオフセット付き |
| `30m 2026-03-15T12:00:00Z` | Absolute | 日時 - 30 分 |
| `2026-03-15T12:00:00Z +5h30m` | Absolute | 日時 + 5h30m |
| `@10:30` | Absolute | 今日の 10:30（時刻リセット） |
| `@10:30+09:00` | Absolute | 今日の 10:30 JST |
| `@1704110400000` | Absolute | 生の epoch ms（`date -d @EPOCH` 形式） |
| `3 minutes ago` | Relative | 英語スタイル修飾子 |

### TimeRange (`parse_range`)

2 引数スタイル（推奨）:

| `since` | `until` | 説明 |
|---------|---------|-------------|
| `5m` | `3m` | 5 分前から 3 分前まで |
| `5m` | _(空)_ | 5 分前から |
| _(空)_ | `3m` | 3 分前まで |
| `@5m` | `3m` | absolute な since、since にアンカーされた relative な until |
| `5m` | `+3m` | 正のオフセットを明示する `+` |

チルダ区切りスタイル（単一文字列）:

| `input` | 等価 |
|---------|------------|
| `5m~3m` | since=`5m`, until=`3m` |
| `5d~` | since=`5d`, until=_(なし)_ |
| `~3m` | since=_(なし)_, until=`3m` |

### タイムゾーンオフセット (`parse_tz_offset`)

| 入力 | 結果 |
|-------|--------|
| `Z`, `UTC`, `GMT` | `Utc` |
| `9`, `+09`, `+09:00`, `+0900` | `Hour(9)` |
| `GMT+9`, `UTC+09:00` | `Hour(9)` |
| `+5:30`, `UTC+5:30` | `Min(330)` |
| `-5h`, `+9h30m` | duration スタイルのオフセット |
| `local` | `Local`（実行時に解決） |

## 再シリアライズ

`TimeSpec::to_cli_string()` は意図を保存します:

| バリアント | 出力 | 用途 |
|---------|--------|----------|
| Relative | `"-5m"`, `"+1h30m"` | 同じ相対オフセットを再現 |
| Absolute | `"2026-03-15T12:00:00Z"` | 厳密な時点を再現 |

## プラガブル設計

すべてのパース関数は妥当なデフォルト値を持つオプションのラベル付き引数を受け取ります:

- **`now`** — カスタムクロックソース（デフォルト: システム時刻）
- **`epoch`** — Snowflake ID や Performance API などのためのカスタム epoch
- **`default_sign`** — `Minus`（`--since` 用）、`Plus`、または `Reject`
- **`default_tz_offset`** — TZ なしの日時入力のためのタイムゾーン
- **`parse_datetime`** — ISO 8601 パーサをロケール対応パーサに差し替え

## マルチターゲット

| ターゲット | ローカル TZ | 備考 |
|--------|----------|-------|
| Native | C FFI (`localtime_r`) | フルサポート |
| JS | `Date.getTimezoneOffset()` | フルサポート |
| WASM | UTC にフォールバック | WASI は TZ API を持たない |

## ライセンス

MIT License - Yoshiaki Kawazu (@kawaz)
