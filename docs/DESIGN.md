# kawaz/timespec 設計書

CLI の `--since` / `--until` 向け時間指定パーサライブラリ。

## 設計原則

1. **CLI用途に特化** — 広大な日時ライブラリではなく、パース＋再シリアライズに集中
2. **精度は妥協しない** — あり得ることは考える。Duration は sub-ms 精度を保持
3. **プラガブル** — now、datetime パーサを差し替え可能
4. **寛容パース、厳密内部表現** — 入力は広く受け付け、正規化して保持
5. **再シリアライズで意図を保存** — Absolute/Relative の区別で「結果」vs「やり方」を表現

## 型定義

### Duration

```moonbit
pub(all) enum Duration {
  Ms(Int64)            // ミリ秒精度
  MsNs(Int64, Int)     // ミリ秒 + サブミリ秒ナノ秒（0..999_999）
}
```

- パース時は ns で累積 → `Duration::from_ns(total_ns: Int64)` で正規化
- `Ms(ms)`: sub_ms_ns が 0 のケース（大半の CLI 用途）
- `MsNs(ms, ns)`: sub_ms_ns が非ゼロ（round-trip fidelity 用）
- 例: `1.2ms900us` → ns累積: 2_100_000 → `MsNs(2, 100_000)`

### TimeSpec

```moonbit
pub(all) enum TimeSpec {
  Absolute(Int64)            // epoch_ms。@ 付きまたはタイムスタンプリテラル
  Relative(Int64, Duration)  // epoch_ms + 元のオフセット（再シリアライズ用）
}
```

Absolute vs Relative の区別は計算結果のためではなく、**CLI 引数の再シリアライズ**のため:
- `Relative` → `--since -8m`（「やり方」の共有。実行するたび結果が変わる）
- `Absolute` → `--since 2025-03-15T00:56:14Z`（「結果」の共有。誰がいつ実行しても同じ）

### TimeRange

```moonbit
pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
}
```

### ParseContext

```moonbit
pub(all) enum ParseContext {
  Since   // --since 用。anchor = since 側
  Until   // --until 用。anchor = until 側
  Range   // --time-range 用。独立解決（ただし Mixed 時は絶対側 anchor）
}
```

ParseContext は `parse` 関数内でのアンカー決定に使用される。
`parse_duration` の `default_sign` とは別のレイヤー（後述「符号の2レイヤー」参照）。

### Sign

```moonbit
pub(all) enum Sign {
  Minus   // 符号なし → 負
  Plus    // 符号なし → 正
  Reject  // 符号省略を拒否（エラー）
}
```

Sign は符号省略時のデフォルト解釈を呼び出し側が指定するためのパラメータ。
`parse_duration` でも `parse` でも `default_sign~` として受け取り、
アプリケーションの文脈に応じて呼び出し側が選択する。

用途例:
- ログ検索: `default_sign~=Minus`（`--since 5m` → 5分前）
- タイマー/予約: `default_sign~=Plus`（`set_timer("3m")` → 3分後）
- 過去/未来両方あり得るクエリ: `default_sign~=Reject`（符号必須、曖昧さ排除）

### TzOffset

```moonbit
pub(all) enum TzOffset {
  Utc          // → Z
  Local        // → ローカルTZ取得
  Hour(Int)    // Hour(9) → +09:00
  Min(Int)     // Min(330) → +05:30
}
```

### ParseError

```moonbit
pub(all) suberror ParseError {
  ParseError(String)
}
```

## 公開 API

```moonbit
// Duration パース
pub fn parse_duration(
  input : String,
  default_sign~ : Sign = Plus
) -> Duration!ParseError

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
  context~ : ParseContext,
  default_sign~ : Sign = Plus,
  now~ : () -> UInt64 = @env.now,
  swap~ : Bool = false,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeRange!ParseError

// TzOffset パース
pub fn parse_tz_offset(s : String) -> TzOffset!ParseError

// 再シリアライズ
pub fn to_cli_string(self : TimeSpec) -> String

// epoch → ISO 8601（TzOffset 対応）
pub fn epoch_to_iso8601(epoch_ms : Int64, tz~ : TzOffset = Utc) -> String

// デフォルト datetime パーサ（差し替え用に公開）
pub fn default_parse_datetime(s : String) -> Int64?
```

## パース仕様

### Duration パース

#### 数値構文
- 整数: `5m`, `300s`
- 小数: `1.5h` → 5400s
- アンダースコア区切り: `3_600_000ms`
- 複合: `1_000.5s`（小数 + アンダースコア両立）

#### サポート単位

| 単位 | 意味 | ナノ秒換算 |
|---|---|---|
| `w` | 週 | × 604_800_000_000_000 |
| `d` | 日 | × 86_400_000_000_000 |
| `h` | 時 | × 3_600_000_000_000 |
| `m` | 分 | × 60_000_000_000 |
| `s` | 秒 | × 1_000_000_000 |
| `ms` | ミリ秒 | × 1_000_000 |
| `μs` / `us` | マイクロ秒 | × 1_000 |
| `ns` | ナノ秒 | × 1 |

`y`, `month` は非対応（可変長で曖昧）。

#### 複合表現
- `1h30m45s` — 連結可能
- `1h5m1h` = `2h5m` — 重複合算、順序無視

#### default_sign

| default_sign | `5m` | `+5m` | `-5m` |
|---|---|---|---|
| Minus | -5m | +5m | -5m |
| Plus | +5m | +5m | -5m |
| Reject | エラー | +5m | -5m |

### TimeSpec パース

1つの timespec パートの構文:

```
[@] [sign] (duration | datetime)+ [@]
```

- `@` は前置・後置どちらも可（`@-5h` = `-5h@`）
- duration と datetime はインターリーブ可能（ただし datetime は最大1つ）
- duration は datetime に対するオフセットとして加算される
- datetime がなければ now 基準の相対指定

#### 入力例

| 入力 | 解釈 |
|---|---|
| `5m` | now - 5m（Relative） |
| `@5m` | now - 5m（Absolute） |
| `-5h@` | now - 5h（Absolute。`@-5h` と同じ） |
| `2026-12-02T13:51:00` | datetime（Absolute） |
| `2026-12-02T13:51:00+5h30m` | datetime + 5h30m（Absolute） |
| `30m2026-12-02T13:51:00` | datetime - 30m（Absolute） |
| `30m2026-12-02T13:51:00+5h30m` | datetime - 30m + 5h30m（Absolute） |
| `@30m2026-12-02T13:51:00+5h30m` | 同上（datetime があれば暗黙 Absolute） |

**制約**: 1パートに datetime は最大1つ。2つ以上の datetime はパースエラー。

### TimeRange パース

入力形式: `[since_part][~until_part]`

`~` は常に since側~until側のポジション固定。context（Since/Until/Range）が anchor を決定。

#### アンカー解決規則

**Anchor 決定（優先順位順）**:

1. **Mixed（片方だけ絶対）** → 絶対側が anchor（context 無関係。Range でも適用）
2. **同種 + Since/Until context** → context 指定側が anchor
3. **同種 + Range context** → anchor なし（各自独立に now 基準で解決）

優先度: Mixed > Since/Until > Range独立

**解決順序**（anchor ありの場合）:
1. Anchor を now 基準で解決（符号なし = Minus = 過去）
2. 非 Anchor を Anchor 基準で解決（符号なし = s<=u を満たす方向）

#### default_sign とアンカー解決の関係

`parse_range` / `parse_timespec` / `parse_duration` はいずれも `default_sign~` を受け取る。
アンカー解決における符号の決定は以下の通り:

| 対象 | 符号なしのデフォルト |
|---|---|
| anchor 側 | `default_sign~` パラメータの値 |
| 非 anchor 側（両方 Relative） | s<=u を満たす方向（cosmetic。明示符号は格納のみ） |
| 非 anchor 側（@ 絡み） | `default_sign~` パラメータの値（明示符号は計算に反映） |

`default_sign~` のデフォルトは `Plus`。アプリケーションの文脈に応じて呼び出し側が選択する。

**符号と計算の関係**:

両方 Relative の場合:
- 明示符号は格納のみ（cosmetic）— 計算は常に s<=u コンテキストが勝つ
- `s 5m~3m` → since=now-5m, until=now-2m (stored: -3m)
- `s 5m~+3m` → 同じ計算結果 (stored: +3m)

@ が絡む場合:
- 明示符号は計算に反映（反転レンジも許容）
- `s @5m~+3m` → since=now-5m, until=since+3m=now-2m
- `s @5m~-3m` → since=now-5m, until=since-3m=now-8m（反転OK）

**swap オプション**: `swap~=true` でパーサ側の s<=u 保証。デフォルトはアプリ判断。

### パース例一覧

#### Since context

| 入力 | since | until |
|---|---|---|
| `5m` | R(now-5m, -5m) | None |
| `5m~3m` | R(now-5m, -5m) | R(now-2m, -3m) |
| `5m~+3m` | R(now-5m, -5m) | R(now-2m, +3m) |
| `5m~-3m` | R(now-5m, -5m) | R(now-2m, -3m) |
| `5m~@3m` | R(u-5m, -5m) | A(now-3m) |
| `@5m` | A(now-5m) | None |
| `@5m~3m` | A(now-5m) | R(s+3m, 3m) |
| `@5m~@3m` | A(now-5m) | A(now-3m) |
| `@5m~@+3m` | A(now-5m) | A(now+3m) |

#### Until context

since と until の anchor が入れ替わる（until が anchor）。

#### Range context

同種（両方 relative or 両方 absolute）の場合、各パートが独立に now 基準で解決。意味的デフォルトなし。
Mixed（片方だけ絶対）の場合は、Range でも絶対側が anchor となり解決される（Anchor 決定の優先順位1に該当）。

### TzOffset パース

| 入力 | 結果 |
|---|---|
| `""`, `"Z"`, `"UTC"` | `Utc` |
| `"9"`, `"+9"`, `"+09"` | `Hour(9)` |
| `"+0900"`, `"+09:00"` | `Hour(9)` |
| `"5h30m"`, `"+5h30m"` | `Min(330)` |
| `"-5h"` | `Hour(-5)` |

### ISO 8601 パース

組み込みの最小限パーサ。プラガブルに差し替え可能。

受け入れ形式:
- `YYYY-MM-DD` — TZ なし → **UTC として解釈**
- `YYYY-MM-DDTHH:MM:SS` — TZ なし → **UTC として解釈**
- `YYYY-MM-DDTHH:MM:SSZ`
- `YYYY-MM-DDTHH:MM:SS±HH:MM`
- 区切り `/` も許容

**TZ なし日時の扱い**: デフォルトパーサは TZ 情報のない入力を **UTC** として解釈する。
これにより `Absolute` の「誰がいつ実行しても同じ結果」という保証が維持される。
ローカル時刻として解釈したい場合は、`parse_datetime~` で TZ 付加するカスタムパーサを差し込む。

### 日付正規化

パースは寛容、内部は厳密に正規化（Go mktime スタイル）。

段階的正規化:
1. 月を 1-12 に正規化（month=0 → year-1, month=12）
2. 年月に対して日を正規化（日数溢れ → 翌月）
3. 時分秒を秒数ベースで加算

## 再シリアライズ

### TimeSpec::to_cli_string()

- `Absolute(epoch_ms)` → ISO 8601 UTC 文字列（例: `2025-03-15T00:56:14Z`）
- `Relative(_, duration)` → 符号付き duration 文字列（例: `-8m`, `+1h30m`）

### epoch_to_iso8601()

- デフォルト: UTC (Z)
- `tz~=Hour(9)` → `+09:00` 付き
- `tz~=Local` → ローカルTZ取得して適用

## 設計判断の記録

詳細は `docs/decision-records/` を参照:
- DR-001: CLI時間指定パーサの基本設計
