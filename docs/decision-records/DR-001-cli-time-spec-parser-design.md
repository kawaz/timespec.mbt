# DR-001: CLI時間指定パーサの基本設計

- **日付**: 2026-03-15
- **ステータス**: Accepted

> **注意**: この DR は初期設計時の記録です。以下の DR により一部が上書きされています:
> - DR-002: EpochTime 型の導入、TimeSpec を (EpochTime, Duration) に変更
> - DR-003: カスタム epoch パラメータの追加
> - DR-004: ms 精度への簡素化（MsNs 廃止、us/ns 廃止、newtype 化）
> - DR-006: ParseContext 廃止、parse_range を since~/until~ 方式に変更、アンカー解決を Mixed ルールのみに

## 概要

MoonBit で CLI の `--since` / `--until` 向け柔軟な日時指定文字列パーサライブラリを設計する。広大な日時ライブラリではなく、CLI 用途に特化した軽量パーサ。

元の着想は `kawaz/claude-session-analysis` の `--since/--until` パーサ。

---

## 1. Duration 型: `Ms(Int64) | MsNs(Int64, Int)` enum

### 決定

Duration は2バリアントの enum とする。

```moonbit
pub(all) enum Duration {
  Ms(Int64)            // ミリ秒精度のみ（大半のCLI用途）
  MsNs(Int64, Int)     // ミリ秒 + サブミリ秒ナノ秒（0..999_999）
}
```

- パース時は ns で累積し、`Duration::from_ns(total_ns)` で正規化する。
- 例: `1.2ms900us` → `MsNs(2, 100_000)`（2ms + 100us）

### 理由

- epoch が ms 精度（`@env.now()` が ms）であっても、Duration は sub-ms 精度を保持すべき。round-trip fidelity（パース → シリアライズ → パースで精度が落ちない）のため。
- `Ms(Int64)` バリアントにより、大半の CLI 用途ではサブミリ秒のオーバーヘッドなしに扱える。

> ユーザー原文: 「精度が必要なケースがほぼ無いとかそんな事はどうでも良い。あり得る事は考えるべき」

### 不採用案

| 案 | 却下理由 |
|---|---|
| 全部ナノ秒 (Go 方式) | シンプルだが `@env.now()` との変換が毎回必要。最大 +/-292年の制約 |
| 全部ミリ秒 | us/ns 精度が完全に失われる |
| `Nanos` / `Millis` enum | 算術演算で毎回 match が必要になり煩雑 |

---

## 2. TimeSpec 型: `Absolute(Int64) | Relative(Int64, Duration)`

### 決定

絶対時刻と相対時刻を区別する enum。epoch は ms (Int64)。

```moonbit
pub(all) enum TimeSpec {
  Absolute(Int64)           // @ 付きまたはタイムスタンプリテラル
  Relative(Int64, Duration) // @ なし
}
```

### 理由

CLI 引数の再シリアライズにおいて、意図の区別が必要。

- `Relative` → `--since -8m` として復元（「やり方」の共有。実行するたび結果が変わる）
- `Absolute` → `--since 2025-03-15T00:56:14Z` として復元（「結果」の共有。誰がいつ実行しても同じ）
- `@` は「この値をピン留めする」宣言として機能する

---

## 3. TimeRange 型

### 決定

```moonbit
pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
}
```

パース入力形式: `since_part~until_part`（`~` は常に since 側 ~ until 側のポジション固定）。

---

## 4. アンカー解決規則

### 4.1 Anchor 決定（優先順位順）

1. **Mixed（片方だけ @/タイムスタンプ）** → 絶対側が anchor（context 無関係。Range でも適用）
2. **同種 + Since/Until context** → context 指定側が anchor
3. **同種 + Range context** → anchor なし（各自独立に now 基準で解決）

優先度: Mixed > Since/Until > Range独立

### 4.2 解決順序（anchor ありの場合）

1. Anchor を now 基準で解決（符号なし = Minus = 過去）
2. 非 Anchor を Anchor 基準で解決（符号なしデフォルト = `s<=u` を満たす方向）

### 4.2.1 default_sign の位置づけ

`parse_duration` も `parse` も `default_sign~` を受け取る（デフォルト: Plus）。
符号省略時の解釈はアプリケーション文脈に応じて呼び出し側が選択する。

- ログ検索: `default_sign~=Minus`（`--since 5m` → 5分前）
- タイマー/予約: `default_sign~=Plus`（`set_timer("3m")` → 3分後）
- 過去/未来両方あり得るクエリ: `default_sign~=Reject`（符号必須、曖昧さ排除）

### 4.3 符号と計算の関係

**両方 Relative の場合**: 明示符号は格納のみ（cosmetic）、計算は常に `s<=u` コンテキストが勝つ。

| 入力 | 計算結果 | stored |
|---|---|---|
| `s 5m~3m` | since=now-5m, until=now-2m | -3m |
| `s 5m~-3m` | 同上 | -3m |
| `s 5m~+3m` | 同上 | +3m |

**@ が絡む場合**: 明示符号は計算に反映（反転レンジも許容）。

| 入力 | 計算結果 |
|---|---|
| `s @5m~+3m` | since=now-5m, until=since+3m=now-2m |
| `s @5m~-3m` | since=now-5m, until=since-3m=now-8m（反転OK）|

### 4.4 swap オプション

- デフォルト: swap なし（アプリが判断）
- `swap=true`: パーサ側で `s<=u` を保証

---

## 5. 符号の default_sign

### 決定

```moonbit
pub fn parse_duration(input : String, default_sign~ : Sign = Plus) -> Duration!ParseError

pub(all) enum Sign { Minus; Plus; Reject }
```

| default_sign | 入力 `5m` | 入力 `+5m` | 入力 `-5m` |
|---|---|---|---|
| `Minus` | -5m | +5m | -5m |
| `Plus` | +5m | +5m | -5m |
| `Reject` | エラー | +5m | -5m |

### 理由

- デフォルトは `Plus`（`timeout=parse_duration("5s")` のような一般用途で正が自然）
- アプリケーション文脈に応じて呼び出し側が `Minus` や `Reject` を選択
- `Reject` は符号省略を禁止するコンテキスト用

---

## 6. パース仕様

### 数値構文

- 小数: `1.5h` → 5400s
- アンダースコア区切り: `3_600_000ms`
- 複合: `1_000.5s`（両方組み合わせ可能）

### サポート単位

`w`, `d`, `h`, `m`, `s`, `ms`, `μs`/`us`, `ns`

### 不採用単位

`y`, `month` は非対応。可変長で曖昧なため。

### 複合表現

`1h30m45s` のように連結可能。`1h5m1h` = `2h5m`（重複合算、順序無視）。

---

## 7. TzOffset 型

### 決定

```moonbit
pub(all) enum TzOffset {
  Utc          // -> Z
  Local        // -> ローカルTZ取得
  Hour(Int)    // Hour(9) -> +09:00
  Min(Int)     // Min(330) -> +05:30
}

pub fn parse_tz_offset(s : String) -> TzOffset!ParseError
```

Parse バリアントは型に含めない（エラー処理の関心分離）。

### パース受け入れパターン

| 入力 | 結果 |
|---|---|
| `""`, `"Z"`, `"UTC"` | `Utc` |
| `"9"`, `"+9"`, `"+09"` | `Hour(9)` |
| `"+0900"`, `"+09:00"` | `Hour(9)` |
| `"5h30m"`, `"+5h30m"` | `Min(330)` |
| `"-5h"` | `Hour(-5)` |

---

## 8. 日付正規化（寛容パース）

### 決定

パースは寛容、内部表現は厳密に正規化する。Go の mktime スタイル。

### 正規化手順

1. 月を 1-12 に正規化（month=14 → 年+1, month=2。month=0 → 年-1, month=12）
2. 確定した年月に対して日を正規化（日数溢れ → 翌月へ繰り上げ）
3. 時分秒を秒数ベースで加算

### 例

`2026-11-32 13:50:60` → パース成功 → `2026-12-02T13:51:00`

---

## 9. プラガブル設計

### 決定

- `now~: () -> UInt64`（デフォルト: `@env.now`）
- `parse_datetime~: (String) -> Int64?`（デフォルト: 組み込み ISO 8601 パーサ）

### 理由

- ISO 8601 パーサは最小限に留め、ロケール依存フォーマットは外部パーサに委譲する。
- テスト時に now を固定できる。

---

## 10. 公開 API 概要

```moonbit
// Duration パース
pub fn parse_duration(input : String, default_sign~ : Sign = Plus) -> Duration!ParseError

// 単一 TimeSpec パース（datetime + duration の複合入力）
pub fn parse_timespec(
  input : String,
  default_sign~ : Sign = Plus,
  now~ : () -> UInt64 = @env.now,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeSpec!ParseError

// TimeRange パース（since~until）
pub fn parse_range(
  input : String,
  context~ : ParseContext,    // Since | Until | Range
  default_sign~ : Sign = Plus,
  now~ : () -> UInt64 = @env.now,
  swap~ : Bool = false,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeRange!ParseError

// TzOffset パース
pub fn parse_tz_offset(s : String) -> TzOffset!ParseError

// 再シリアライズ
pub fn TimeSpec::to_cli_string(self : TimeSpec) -> String
// Absolute -> ISO 8601 UTC
// Relative -> 符号付き duration 文字列

// デフォルト datetime パーサ（差し替え用に公開）
pub fn default_parse_datetime(s : String) -> Int64?
```

---

## 11. 参考実装

元の着想は `kawaz/claude-session-analysis` の `--since/--until` パーサ。
