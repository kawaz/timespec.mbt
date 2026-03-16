# kawaz/timespec 設計書

CLI の `--since` / `--until` 向け時間指定パーサライブラリ。

## 設計原則

1. **CLI用途に特化** — 広大な日時ライブラリではなく、パース＋再シリアライズに集中
2. **ミリ秒精度** — CLI 用途で十分な ms 精度に統一。シンプルな newtype で表現
3. **プラガブル** — now、datetime パーサを差し替え可能
4. **寛容パース、厳密内部表現** — 入力は広く受け付け、正規化して保持
5. **再シリアライズで意図を保存** — Absolute/Relative の区別で「結果」vs「やり方」を表現

## 型定義

### Duration（期間）

```moonbit
pub(all) struct Duration(Int64)  // ミリ秒
```

newtype。内部値はミリ秒。`Duration(5000L)` で構築、`d.0` で内部値にアクセス。

### EpochTime（時点）

```moonbit
pub(all) struct EpochTime(Int64)  // epoch からの経過ミリ秒
```

Duration と対をなす概念。構造は同じだが「期間」ではなく「時点」を表す。

### TimeSpec

```moonbit
pub(all) enum TimeSpec {
  Absolute(EpochTime, Duration)   // 絶対時刻 + 元のオフセット
  Relative(EpochTime, Duration)   // 相対時刻 + 元のオフセット
}
```

両バリアントが `(EpochTime, Duration)` を持つ。違いは**再シリアライズの挙動**:
- `Relative` → `--since -8m`（「やり方」の共有。実行するたび結果が変わる）
- `Absolute` → `--since 2025-03-15T00:56:14Z`（「結果」の共有。誰がいつ実行しても同じ）

Duration フィールドはオフセットの元情報を保持する（例: `@5m` → Duration は `-5m`）。
datetime のみの入力では Duration は `Duration(0L)`。

### TimeRange

```moonbit
pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
}
```

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
} derive(Eq, Show)
```

## 公開 API

```moonbit
// Duration パース
pub fn parse_duration(
  input : String,
  default_sign~ : Sign = Plus
) -> Duration!ParseError

// 単一 TimeSpec パース（datetime + duration の複合入力、マルチパス方式）
pub fn parse_timespec(
  input : String,
  epoch~ : EpochTime = EpochTime(0L),
  default_sign~ : Sign = Plus,
  default_tz_offset~ : TzOffset = Utc,
  now~ : () -> UInt64 = @env.now,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeSpec!ParseError

// TimeRange パース
pub fn parse_range(
  input~ : String = "",
  since~ : String = "",
  until~ : String = "",
  epoch~ : EpochTime = EpochTime(0L),
  default_sign~ : Sign = Plus,
  default_tz_offset~ : TzOffset = Utc,
  now~ : () -> UInt64 = @env.now,
  swap~ : Bool = false,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeRange!ParseError

// TzOffset パース
pub fn parse_tz_offset(s : String) -> TzOffset!ParseError

// 再シリアライズ
pub fn TimeSpec::to_cli_string(self : TimeSpec, epoch~ : EpochTime = EpochTime(0L)) -> String

// epoch → ISO 8601（TzOffset 対応）
pub fn epoch_to_iso8601(epoch_ms : Int64, tz_offset~ : TzOffset = Utc) -> String raise ParseError

// デフォルト datetime パーサ（差し替え用に公開）
pub fn default_parse_datetime(s : String) -> Int64?

// カスタム TZ 付き datetime パーサ生成
pub fn make_parse_datetime(default_tz_offset~ : TzOffset = Utc) -> (String) -> Int64?

// ローカルタイムゾーンオフセット取得
pub fn local_tz_offset() -> TzOffset

// Duration 定数
pub let millisecond : Duration  // Duration(1L)
pub let second : Duration       // Duration(1_000L)
pub let minute : Duration       // Duration(60_000L)
pub let hour : Duration         // Duration(3_600_000L)
pub let day : Duration          // Duration(86_400_000L)
pub let week : Duration         // Duration(604_800_000L)

// Duration 演算（trait 実装）
pub impl Add for Duration       // Duration + Duration
pub impl Sub for Duration       // Duration - Duration
pub impl Neg for Duration       // -Duration

// Duration スカラ倍
pub fn Duration::scale(self : Duration, n : Int64) -> Duration

// EpochTime に Duration を加算
pub fn EpochTime::add_duration(self : EpochTime, d : Duration) -> EpochTime

// TzOffset の意味的等価比較（分単位で解決して比較。Hour(9) == Min(540)）
pub fn TzOffset::equal_offset(self : TzOffset, other : TzOffset) -> Bool
```

## パース仕様

### Duration パース

#### 数値構文
- 整数: `5m`, `300s`
- 小数: `1.5h` → 5400s
- アンダースコア区切り: `3_600_000ms`
- 複合: `1_000.5s`（小数 + アンダースコア両立）

#### サポート単位

| 単位 | エイリアス | 意味 | ミリ秒換算 |
|---|---|---|---|
| `w` | `wk`, `week`, `weeks` | 週 | × 604_800_000 |
| `d` | `day`, `days` | 日 | × 86_400_000 |
| `h` | `hr`, `hour`, `hours` | 時 | × 3_600_000 |
| `m` | `min`, `minute`, `minutes` | 分 | × 60_000 |
| `s` | `sec`, `second`, `seconds` | 秒 | × 1_000 |
| `ms` | `millisecond`, `milliseconds` | ミリ秒 | × 1 |

`y`, `month` は非対応（可変長で曖昧）。
`μs`/`us`, `ns` は非対応（ms 精度に統一）。指定するとエラー。

#### 複合表現
- `1h30m45s` — 連結可能
- `1hour 30m` — 短縮形とエイリアスの混在可
- `1h5m1h` = `2h5m` — 重複合算、順序無視

#### `ago` 修飾子（グループレベル反転）

`ago` は直前の **グループ** の符号を反転する。グループとは明示的 `+`/`-` で区切られた連続セグメントの塊。

- 暗黙連結（スペースのみ）はグループを分けない
- `ago` の後は新しいグループが始まる（group_sign = +1）
- 先頭符号（`+`/`-`/`default_sign`）は最後に全体に適用され、`ago` とは独立

| 入力 | 解釈 | 結果 |
|---|---|---|
| `3 minutes ago` | グループ[3m]を反転 | -3m |
| `1 hour 30 minutes ago` | グループ[1h+30m]を反転 | -90m |
| `1 hour + 30 minutes ago` | グループ[1h] + グループ[30m]を反転 | 30m |
| `1 hour - 30 minutes ago` | グループ[1h] - グループ[30m]を反転 | 90m |
| `30 minutes ago 1h` | グループ[30m]を反転, 新グループ[1h] | 30m |
| `30 minutes ago - 1h` | グループ[30m]を反転, -グループ[1h] | -90m |
| `-5m ago` | 先頭`-`で全体反転, グループ[5m]を反転 → +5m | +5m |

`ago` は `default_sign` とは独立。`default_sign=Plus` でも `5m ago` = `-5m`。

#### default_sign

| default_sign | `5m` | `+5m` | `-5m` |
|---|---|---|---|
| Minus | -5m | +5m | -5m |
| Plus | +5m | +5m | -5m |
| Reject | エラー | +5m | -5m |

### TimeSpec パース

1つの timespec パートの構文:

```
[@] [sign] (duration | datetime | time-of-day)+ [@]
```

- `@` は前置・後置どちらも可（`@-5h` = `-5h@`）。セグメント間にも配置可能（`1h@30m` = `@1h30m`）
- duration と datetime はインターリーブ可能（ただし datetime は最大1つ）
- duration は datetime に対するオフセットとして加算される
- datetime がなければ now 基準の相対指定
- `@HH:MM[:SS[.mmm]][TZ]` で今日の指定時刻にリセット（`@` 必須）

#### マルチパスパーサ

`parse_timespec` は入力文字列を6フェーズで処理する:

1. **Phase 1: Leading sign + Duration segment extraction** — 先頭符号の検出と duration セグメント（数値+単位+ago）の抽出・累積。非 duration 部分はバッファに蓄積
2. **Phase 2: `@` マーカー検出** — Phase 1 の走査中に `@` の有無を記録
3. **Phase 3: Time-of-day パターンの検出** — `@` 付きで残り文字列に `:` を含む場合、`HH:MM[:SS[.mmm]][TZ]` として解釈。TzOffset 整合性チェックも実施
4. **Phase 3.5: Raw epoch ms の検出** — `@` 付きで残り文字列が `[+-]?[0-9]+` のみの場合、raw epoch ms として解釈（`date -d @EPOCH` 規約。例: `@1704110400000`, `@-100`）
5. **Phase 4: datetime パース** — 残りの非 duration 文字列を `parse_datetime~` でパース
6. **Phase 5-6: EpochTime / TimeSpec の構築** — 基準 epoch の決定、time-of-day リセット、duration 加算、Absolute/Relative の判定

#### 入力例

以下は `default_sign~=Minus` を前提とした例。`default_sign~=Plus`（デフォルト）の場合は符号なし duration の方向が反転する。

| 入力 | 解釈（default_sign=Minus） |
|---|---|
| `5m` | now - 5m（Relative） |
| `@5m` | now - 5m（Absolute） |
| `-5h@` | now - 5h（Absolute。`@-5h` と同じ） |
| `2026-12-02T13:51:00` | datetime（Absolute） |
| `2026-12-02T13:51:00+5h30m` | datetime + 5h30m（Absolute） |
| `30m2026-12-02T13:51:00` | datetime - 30m（Absolute。default_sign=Minus） |
| `30m2026-12-02T13:51:00+5h30m` | datetime - 30m + 5h30m（Absolute） |
| `@30m2026-12-02T13:51:00+5h30m` | 同上（datetime があれば暗黙 Absolute） |
| `@1704110400000` | raw epoch ms（Absolute） |
| `@-100` | raw epoch ms（負値、Absolute） |
| `@09:30` | 今日の 09:30 UTC（Absolute） |
| `@09:30+09:00` | 今日の 09:30 JST（Absolute） |

**制約**: 1パートに datetime は最大1つ。2つ以上の datetime はパースエラー。

### TimeRange パース

`parse_range` は3つの入力方式をサポートする。

#### 入力方式

**方式1: 2引数（推奨）** — `since~` / `until~` を個別に指定

```moonbit
// CLI の --since / --until に直接対応
parse_range(since="5m", until="3m", default_sign=Minus)
parse_range(since="5m", default_sign=Minus)     // since のみ
parse_range(until="3m", default_sign=Minus)     // until のみ
```

**方式2: `~` 形式** — `input~` に `since~until` 文字列を渡す

```moonbit
// 単一引数で since/until を表現（~ で分割される）
parse_range(input="5m~3m", default_sign=Minus)  // since="5m", until="3m"
parse_range(input="5d~", default_sign=Minus)    // since="5d", until なし
parse_range(input="~3m", default_sign=Minus)    // since なし, until="3m"
parse_range(input="5m", default_sign=Minus)     // ~ なし → since="5m"
```

**方式3: 混合** — `since~` / `until~` が明示されていれば `input~` より優先

```moonbit
// input を上書き
parse_range(input="99d~99d", since="5m", until="3m")  // since="5m", until="3m" が使われる
```

#### 優先順位

1. `since~` / `until~` が空でなければそれを使う
2. 両方空のとき `input~` があれば `~` で分割して展開
3. 全て空なら `TimeRange { since: None, until: None }`

#### パース動作

- `since` が空でなければ `parse_timespec(since, ...)` でパース → `TimeRange.since`
- `until` が空でなければ `parse_timespec(until, ...)` でパース → `TimeRange.until`
- 両方空なら `TimeRange { since: None, until: None }` を返す

#### アンカー解決規則

両方指定された場合のみアンカー解決が行われる。ルールは **Mixed のみ**:

- **Mixed（片方だけ Absolute）** → 絶対側が anchor。相対側を anchor 基準で再計算（明示符号に従う）
- **同種（両方 Relative or 両方 Absolute）** → 独立解決（各自 now 基準で既にパース済み）

#### 符号と計算の関係

Mixed の場合:
- 明示符号は計算に反映（反転レンジも許容）
- `since="@5m", until="+3m"` → since=A(now-5m), until=R(since+3m)
- `since="@5m", until="-3m"` → since=A(now-5m), until=R(since-3m)

同種の場合:
- 各パートが独立に now 基準で解決済み
- `since="5m", until="3m"` → since=R(now-5m), until=R(now-3m)

**swap オプション**: `swap~=true` でパーサ側の s<=u 保証。デフォルトはアプリ判断。

### パース例一覧

凡例: `R` = `Relative`, `A` = `Absolute`, `s` = since の epoch, `u` = until の epoch

以下は `default_sign~=Minus` を前提とした例。

| since | until | since 結果 | until 結果 |
|---|---|---|---|
| `5m` | (空) | R(now-5m, -5m) | None |
| (空) | `5m` | None | R(now-5m, -5m) |
| `5m` | `3m` | R(now-5m, -5m) | R(now-3m, -3m) |
| `5m` | `+3m` | R(now-5m, -5m) | R(now+3m, +3m) |
| `5m` | `@3m` | R(u-5m, -5m) | A(now-3m) |
| `@5m` | (空) | A(now-5m) | None |
| `@5m` | `3m` | A(now-5m) | R(s-3m, -3m) |
| `@5m` | `+3m` | A(now-5m) | R(s+3m, +3m) |
| `@5m` | `@3m` | A(now-5m) | A(now-3m) |
| `@5m` | `@+3m` | A(now-5m) | A(now+3m) |

### TzOffset パース

| 入力 | 結果 |
|---|---|
| `""`, `"Z"`, `"UTC"`, `"GMT"` | `Utc` |
| `"9"`, `"+9"`, `"+09"` | `Hour(9)` |
| `"GMT+9"`, `"GMT+0900"`, `"GMT+09:00"` | `Hour(9)` |
| `"UTC+5:30"` | `Min(330)` |
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
- `HH:MM[:SS[.mmm]][TZ]` — time-only（日付は 1970-01-01 として解釈）
- 区切り `/` も許容

**TZ なし日時の扱い**: デフォルトパーサは TZ 情報のない入力を **UTC** として解釈する。
`default_tz_offset~` パラメータで変更可能（`parse_timespec`、`parse_range` から伝播）。
これにより `Absolute` の「誰がいつ実行しても同じ結果」という保証が維持される。
ローカル時刻として解釈したい場合は、`default_tz_offset~=Local` を指定するか、
`parse_datetime~` で TZ 付加するカスタムパーサを差し込む。

### 日付正規化

パースは寛容、内部は厳密に正規化（Go mktime スタイル）。

段階的正規化:
1. 月を 1-12 に正規化（month=0 → year-1, month=12）
2. 年月に対して日を正規化（日数溢れ → 翌月）
3. 時分秒を秒数ベースで加算

## 再シリアライズ

### TimeSpec::to_cli_string()

- `Absolute(instant, _)` → instant の epoch から ISO 8601 UTC 文字列（例: `2025-03-15T00:56:14Z`）
- `Relative(_, duration)` → 符号付き duration 文字列（例: `-8m`, `+1h30m`）

### epoch_to_iso8601()

- デフォルト: UTC (Z)
- `tz_offset~=Hour(9)` → `+09:00` 付き
- `tz_offset~=Local` → ローカルTZ取得して適用

## 設計判断の記録

詳細は `docs/decision-records/` を参照:
- DR-001: CLI時間指定パーサの基本設計
- DR-002: EpochTime 型の導入と sub-ms 精度の epoch
- DR-003: カスタム epoch パラメータ
- DR-004: ms 精度への簡素化
- DR-005: TzOffset の範囲バリデーションと pub(all) 維持
- DR-006: セッション中の設計決定まとめ
- DR-007: TimeSpec マルチパスパーサ
- DR-008: 追加の設計決定（@冪等性、Eq方針、部分日付、UTCデフォルト、raw epoch）
