# kawaz/timespec Design Document

> English | [日本語](./DESIGN-ja.md)

A time specification parser library for CLI `--since` / `--until` options.

## Design Principles

1. **Focused on CLI use** — Not a vast date/time library; concentrates on parsing and re-serialization
2. **Millisecond precision** — Unified at ms precision, which is sufficient for CLI use. Represented as a simple newtype
3. **Pluggable** — `now` and the datetime parser are replaceable
4. **Lenient parsing, strict internal representation** — Accepts input broadly; normalizes for storage
5. **Re-serialization preserves intent** — The Absolute/Relative distinction expresses "result" vs. "method"

## Type Definitions

### Duration

```moonbit
pub(all) struct Duration(Int64)  // ミリ秒
```

A newtype. The internal value is in milliseconds. Construct with `Duration(5000L)`; access the inner value via `d.0`.

### EpochTime

```moonbit
pub(all) struct EpochTime(Int64)  // epoch からの経過ミリ秒
```

A concept paired with Duration. The structure is the same, but it represents a "point in time" rather than a "duration."

### TimeSpec

```moonbit
pub(all) enum TimeSpec {
  Absolute(EpochTime, Duration)   // 絶対時刻 + 元のオフセット
  Relative(EpochTime, Duration)   // 相対時刻 + 元のオフセット
}
```

Both variants carry `(EpochTime, Duration)`. The difference lies in **re-serialization behavior**:
- `Relative` → `--since -8m` (sharing the "method"; the result changes on each execution)
- `Absolute` → `--since 2025-03-15T00:56:14Z` (sharing the "result"; identical no matter who runs it when)

The Duration field retains the original offset information (e.g., `@5m` → Duration is `-5m`).
For datetime-only input, Duration is `Duration(0L)`.

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

`Sign` is a parameter by which the caller specifies the default interpretation when a sign is omitted.
Both `parse_duration` and `parse` accept it as `default_sign`, allowing the caller to choose
based on the application context.

Example use cases:
- Log search: `default_sign=Minus` (`--since 5m` → 5 minutes ago)
- Timer/reservation: `default_sign=Plus` (`set_timer("3m")` → 3 minutes from now)
- Queries that may go either way (past or future): `default_sign=Reject` (sign required; eliminates ambiguity)

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

## Public API

```moonbit
// Duration パース
pub fn parse_duration(
  input : String,
  default_sign? : Sign = Plus
) -> Duration!ParseError

// 単一 TimeSpec パース（datetime + duration の複合入力、マルチパス方式）
pub fn parse_timespec(
  input : String,
  epoch? : EpochTime = EpochTime(0L),
  default_sign? : Sign = Plus,
  default_tz_offset? : TzOffset = Local,
  now? : () -> UInt64 = @env.now,
  parse_datetime? : (String) -> Int64? = default_parse_datetime
) -> TimeSpec?!ParseError

// TimeRange パース
pub fn parse_range(
  input? : String = "",
  since? : String = "",
  until? : String = "",
  epoch? : EpochTime = EpochTime(0L),
  default_sign? : Sign = Plus,
  default_tz_offset? : TzOffset = Local,
  now? : () -> UInt64 = @env.now,
  swap? : Bool = false,
  parse_datetime? : (String) -> Int64? = default_parse_datetime
) -> TimeRange!ParseError

// TzOffset パース
pub fn parse_tz_offset(s : String) -> TzOffset!ParseError

// 再シリアライズ
pub fn TimeSpec::to_cli_string(self : TimeSpec, epoch? : EpochTime = EpochTime(0L)) -> String

// epoch → ISO 8601（TzOffset 対応）
pub fn epoch_to_iso8601(epoch_ms : Int64, tz_offset? : TzOffset = Utc) -> String

// デフォルト datetime パーサ（差し替え用に公開）
pub fn default_parse_datetime(s : String) -> Int64?

// カスタム TZ 付き datetime パーサ生成
pub fn make_parse_datetime(default_tz_offset? : TzOffset = Local) -> (String) -> Int64?

// ローカルタイムゾーンオフセット取得
pub fn local_tz_offset() -> TzOffset

// Duration アクセサ
pub fn Duration::to_ms(self : Duration) -> Int64

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

// EpochTime アクセサ
pub fn EpochTime::to_ms(self : EpochTime) -> Int64

// EpochTime に Duration を加算
pub fn EpochTime::add_duration(self : EpochTime, d : Duration) -> EpochTime

// TimeSpec アクセサ
pub fn TimeSpec::epoch(self : TimeSpec) -> EpochTime
pub fn TimeSpec::duration(self : TimeSpec) -> Duration
pub fn TimeSpec::is_absolute(self : TimeSpec) -> Bool
pub fn TimeSpec::to_epoch_ms(self : TimeSpec) -> Int64

// TzOffset の意味的等価比較（分単位で解決して比較。Hour(9) == Min(540)）
pub fn TzOffset::equal_offset(self : TzOffset, other : TzOffset) -> Bool
```

## Parse Specification

### Duration Parsing

#### Numeric Syntax
- Integer: `5m`, `300s`
- Decimal: `1.5h` → 5400s
- Underscore separators: `3_600_000ms`
- Combined: `1_000.5s` (decimals and underscores together)

#### Supported Units

| Unit | Aliases | Meaning | Milliseconds |
|---|---|---|---|
| `w` | `week`, `weeks` | week | × 604_800_000 |
| `d` | `day`, `days` | day | × 86_400_000 |
| `h` | `hour`, `hours` | hour | × 3_600_000 |
| `m` | `min`, `minute`, `minutes` | minute | × 60_000 |
| `s` | `sec`, `second`, `seconds` | second | × 1_000 |
| `ms` | `millisecond`, `milliseconds` | millisecond | × 1 |

`y` and `month` are unsupported (variable length, ambiguous).

#### Composite Expressions
- `1h30m45s` — concatenable
- `1hour 30m` — shortened forms and aliases can be mixed
- `1h5m1h` = `2h5m` — duplicates accumulate; order doesn't matter

#### `ago` Modifier (Group-level Inversion)

`ago` inverts the sign of the immediately preceding **group**. A group is a cluster of consecutive segments delimited by explicit `+`/`-` signs.

- Implicit concatenation (whitespace only) does not split groups
- A new group begins after `ago` (group_sign = +1)
- The leading sign (`+`/`-`/`default_sign`) is applied to the whole at the end and is independent of `ago`

| Input | Interpretation | Result |
|---|---|---|
| `3 minutes ago` | invert group [3m] | -3m |
| `1 hour 30 minutes ago` | invert group [1h+30m] | -90m |
| `1 hour + 30 minutes ago` | group [1h] + invert group [30m] | 30m |
| `1 hour - 30 minutes ago` | group [1h] - invert group [30m] | 90m |
| `30 minutes ago 1h` | invert group [30m], new group [1h] | 30m |
| `30 minutes ago - 1h` | invert group [30m], -group [1h] | -90m |
| `-5m ago` | leading `-` inverts everything, invert group [5m] → +5m | +5m |

`ago` is independent of `default_sign`. Even with `default_sign=Plus`, `5m ago` = `-5m`.

#### default_sign

| default_sign | `5m` | `+5m` | `-5m` |
|---|---|---|---|
| Minus | -5m | +5m | -5m |
| Plus | +5m | +5m | -5m |
| Reject | error | +5m | -5m |

### TimeSpec Parsing

Syntax of a single timespec part:

```
[@] [sign] (duration | datetime | time-of-day | keyword)+ [@]
```

- `@` may appear either as a prefix or suffix (`@-5h` = `-5h@`). It can also be placed between segments (`1h@30m` = `@1h30m`)
- `duration` and `datetime` may be interleaved (but at most one `datetime`)
- `duration` is added as an offset to the `datetime`
- Without a datetime, the spec is relative to `now`
- `@HH:MM[:SS[.mmm]][TZ]` resets to the specified time today (the `@` is required)

#### Keywords

| Keyword | Case | Result |
|---|---|---|
| `now` | case-insensitive | `Relative(now, Duration(0))` — current time (relative) |
| `@now` | case-insensitive | `Absolute(now, Duration(0))` — current time (absolute) |
| `@` | — | equivalent to `@now` (when `@` appears alone) |
| `none`, `null`, `nil` | case-insensitive | returns `None` (the None of TimeSpec?; explicit reset) |

`none`/`null`/`nil` are intended for resetting one side when combined with `parse_range`'s tilde notation (e.g., `none~5m`, `5m~nil`).

#### Multi-pass Parser

`parse_timespec` processes the input string in six phases:

1. **Phase 1: Leading sign + Duration segment extraction** — Detect the leading sign and extract/accumulate duration segments (numeric + unit + ago). Non-duration parts are accumulated in a buffer
2. **Phase 2: `@` marker detection** — Record the presence of `@` during the Phase 1 scan
3. **Phase 3: Time-of-day pattern detection** — If `@` is present and the remaining string contains `:`, interpret as `HH:MM[:SS[.mmm]][TZ]`. TzOffset consistency check is also performed
4. **Phase 3.5: Raw epoch ms detection** — If `@` is present and the remaining string consists only of `[+-]?[0-9]+`, interpret as raw epoch ms (`date -d @EPOCH` convention; e.g., `@1704110400000`, `@-100`)
5. **Phase 4: datetime parsing** — Parse the remaining non-duration string via `parse_datetime`. TZ information is recovered with `detect_tz_suffix` in a parser-independent way
6. **Phase 5-6: EpochTime / TimeSpec construction** — Determine the base epoch, apply time-of-day reset, add the duration, decide Absolute/Relative

#### Input Examples

The examples below assume `default_sign=Minus`. With `default_sign=Plus` (default), the direction of unsigned durations is reversed.

| Input | Interpretation (default_sign=Minus) |
|---|---|
| `5m` | now - 5m (Relative) |
| `@5m` | now - 5m (Absolute) |
| `-5h@` | now - 5h (Absolute; same as `@-5h`) |
| `2026-12-02T13:51:00` | datetime (Absolute) |
| `2026-12-02T13:51:00+5h30m` | datetime + 5h30m (Absolute) |
| `30m2026-12-02T13:51:00` | datetime - 30m (Absolute; default_sign=Minus) |
| `30m2026-12-02T13:51:00+5h30m` | datetime - 30m + 5h30m (Absolute) |
| `@30m2026-12-02T13:51:00+5h30m` | same as above (implicitly Absolute when a datetime is present) |
| `@1704110400000` | raw epoch ms (Absolute) |
| `@-100` | raw epoch ms (negative value, Absolute) |
| `@09:30` | today's 09:30 UTC (Absolute) |
| `@09:30+09:00` | today's 09:30 JST (Absolute) |

**Constraint**: At most one datetime per part. Two or more datetimes produce a parse error.

### TimeRange Parsing

`parse_range` supports three input methods.

#### Input Methods

**Method 1: Two arguments (recommended)** — Specify `since` / `until` separately

```moonbit
// CLI の --since / --until に直接対応
parse_range(since="5m", until="3m", default_sign=Minus)
parse_range(since="5m", default_sign=Minus)     // since のみ
parse_range(until="3m", default_sign=Minus)     // until のみ
```

**Method 2: Tilde (`~`)-delimited form** — Pass a tilde-separated `since~until` string in `input`

```moonbit
// 単一引数で since/until を表現（~ で分割される）
parse_range(input="5m~3m", default_sign=Minus)  // since="5m", until="3m"
parse_range(input="5d~", default_sign=Minus)    // since="5d", until なし
parse_range(input="~3m", default_sign=Minus)    // since なし, until="3m"
parse_range(input="5m", default_sign=Minus)     // ~ なし → since="5m"
```

Specifying `input` together with `since`/`until` raises `ParseError`.

#### Behavior

#### Parsing Behavior

- If `since` is non-empty, parse with `parse_timespec(since, ...)` → `TimeRange.since`
- If `until` is non-empty, parse with `parse_timespec(until, ...)` → `TimeRange.until`
- If both are empty, return `TimeRange { since: None, until: None }`

#### Anchor Resolution Rules

Anchor resolution runs only when both are specified. The rule applies **only in the Mixed case**:

- **Mixed (only one side is Absolute)** → the absolute side becomes the anchor. The relative side is recalculated against the anchor (following its explicit sign)
- **Same kind (both Relative or both Absolute)** → resolved independently (each is already parsed against `now`)

#### Relationship Between Sign and Computation

In the Mixed case:
- Explicit signs are reflected in the computation (inverted ranges are also allowed)
- `since="@5m", until="+3m"` → since=A(now-5m), until=R(since+3m)
- `since="@5m", until="-3m"` → since=A(now-5m), until=R(since-3m)

In the same-kind case:
- Each part has already been resolved independently against `now`
- `since="5m", until="3m"` → since=R(now-5m), until=R(now-3m)

**swap option**: With `swap=true`, the parser ensures s<=u. By default, this is left to the application.

### Parse Examples

The examples below assume `default_sign=Minus`.

| since | until | since result | until result |
|---|---|---|---|
| `5m` | (empty) | Relative(now-5m, -5m) | None |
| (empty) | `5m` | None | Relative(now-5m, -5m) |
| `5m` | `3m` | Relative(now-5m, -5m) | Relative(now-3m, -3m) |
| `5m` | `+3m` | Relative(now-5m, -5m) | Relative(now+3m, +3m) |
| `5m` | `@3m` | Relative(until-5m, -5m) | Absolute(now-3m) |
| `@5m` | (empty) | Absolute(now-5m) | None |
| `@5m` | `3m` | Absolute(now-5m) | Relative(since-3m, -3m) |
| `@5m` | `+3m` | Absolute(now-5m) | Relative(since+3m, +3m) |
| `@5m` | `@3m` | Absolute(now-5m) | Absolute(now-3m) |
| `@5m` | `@+3m` | Absolute(now-5m) | Absolute(now+3m) |

### TzOffset Parsing

| Input | Result |
|---|---|
| `""`, `"Z"`, `"UTC"`, `"GMT"` | `Utc` |
| `"9"`, `"+9"`, `"+09"` | `Hour(9)` |
| `"GMT+9"`, `"GMT+0900"`, `"GMT+09:00"` | `Hour(9)` |
| `"UTC+5:30"` | `Min(330)` |
| `"+0900"`, `"+09:00"` | `Hour(9)` |
| `"5h30m"`, `"+5h30m"` | `Min(330)` |
| `"-5h"` | `Hour(-5)` |

### ISO 8601 Parsing

A built-in minimal parser. Pluggably replaceable.

Accepted formats:
- `YYYY-MM-DD` — without TZ → **interpreted as Local** (default). **YMD (year/month/day) are all required**
- `YYYY-MM-DDTHH:MM:SS` — without TZ → **interpreted as Local**
- `YYYY-MM-DDTHH:MM:SSZ`
- `YYYY-MM-DDTHH:MM:SS±HH:MM`
- `HH:MM[:SS[.mmm]][TZ]` — time-only (date is interpreted as 1970-01-01)
- `/` is also accepted as a separator

**Rejected formats**:
- `YYYY` (year only) — error
- `YYYY-MM` (year-month only) — error

Reason for rejecting partial dates: short `+/-HH` TZ offsets (`+09`, `-5`, etc.) and the trailing components of partial dates (`-01`, `-9`) become syntactically ambiguous. Requiring full YMD removes the ambiguity (→ DR-0009).

**Handling of TZ-less date-times**: By default, input without TZ information is interpreted as the **local time zone** (ISO 8601 compliant).
This is configurable via the `default_tz_offset` parameter (e.g., `default_tz_offset=Utc` to fix it to UTC).

### TZ Suffix Detection (detect_tz_suffix)

`detect_tz_suffix(String) -> TzOffset?` is a parser-independent utility that detects a TZ suffix from the end of a string.

Detection patterns:
| Pattern | Example | Result |
|---|---|---|
| `Z` / `z` | `...Z` | `Utc` |
| `±HH:MM` | `...+09:00` | `Hour(9)` |
| `±HHMM` | `...+0900` | `Hour(9)` |
| `±HH` / `±H` | `...+09`, `...+9` | `Hour(9)` |

**Safety condition for `±HH` / `±H`**: Detected only when the character before the sign is a digit and the string contains a colon (a time component). This avoids misreading `-15` in `2024-01-15` as a TZ. Since partial dates are forbidden, inputs like `2024-01` are assumed never to arrive.

**Purpose**: In Phase 4, it recovers TZ information from the result of `parse_datetime` (including custom parsers). Because it works independently of `parse_iso8601`'s internal TZ parsing, the TZ consistency check still works when a pluggable custom datetime parser is in use. Unlike `parse_tz_offset` (which interprets the entire string as a TZ), it targets only the trailing portion of a datetime string.

### Date Normalization

Parsing is lenient; the internal form is strictly normalized (Go mktime style).

Staged normalization:
1. Normalize the month to 1-12 (month=0 → year-1, month=12)
2. Normalize the day against the resulting year/month (overflow → next month)
3. Add hours/minutes/seconds on a millisecond basis

## Re-serialization

### TimeSpec::to_cli_string()

- `Absolute(instant, _)` → an ISO 8601 UTC string from the epoch of `instant` (e.g., `2025-03-15T00:56:14Z`)
- `Relative(_, duration)` → a signed duration string (e.g., `-8m`, `+1h30m`)

### epoch_to_iso8601()

- Default: UTC (Z)
- `tz_offset=Hour(9)` → with `+09:00`
- `tz_offset=Local` → obtain and apply the local TZ

## Decision Records

See [`docs/decisions/`](./decisions/INDEX.md) for details:
- DR-0003: Custom epoch parameter
- DR-0005: TzOffset range validation and retaining pub(all)
- DR-0006: Design decisions summary (parse_range method, ago, EpochTime naming, FFI, etc.)
- DR-0007: TimeSpec multi-pass parser
- DR-0008: Additional design decisions (@ idempotency, Eq policy, partial dates, Local default, raw epoch)
- DR-0009: Forbidding partial dates and introducing detect_tz_suffix
