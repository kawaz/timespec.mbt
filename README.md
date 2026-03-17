# kawaz/timespec

CLI-oriented time specification parser for MoonBit.

Parses flexible time expressions like `5m`, `@1h30m`, `2026-03-15T12:00:00Z+5h`, `3 minutes ago` into structured `TimeSpec` values for `--since` / `--until` style CLI options.

## Install

```
moon add kawaz/timespec
```

## Quick Start

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

## Supported Expressions

### Duration (`parse_duration`)

| Input | Parsed as |
|-------|-----------|
| `5m` | 5 minutes |
| `1h30m` | 1 hour 30 minutes |
| `1.5h` | 1.5 hours (= 90 minutes) |
| `500ms` | 500 milliseconds |
| `3_600_000ms` | underscore separators |
| `2d12h` | 2 days 12 hours |
| `5 minutes ago` | -5 minutes (`ago` reverses sign) |
| `+1h -30m` | 1 hour minus 30 minutes (= 30 minutes) |

**Units**: `w`/`week(s)`, `d`/`day(s)`, `h`/`hour(s)`, `m`/`min`/`minute(s)`, `s`/`sec`/`second(s)`, `ms`/`millisecond(s)`

### TimeSpec (`parse_timespec`)

The `@` marker pins a time expression as **Absolute** (re-serializes to ISO 8601). Without `@`, duration-only inputs are **Relative** (re-serializes to signed duration like `+5m`).

Examples with `default_sign=Minus`:

| Input | Kind | Description |
|-------|------|-------------|
| `5m` | Relative | 5 minutes ago from now |
| `+5m` | Relative | 5 minutes from now |
| `@5m` | Absolute | 5 minutes ago, pinned |
| `-5h@` | Absolute | `@` position is flexible |
| `2026-03-15T12:00:00Z` | Absolute | ISO 8601 datetime |
| `2026-03-15T21:00:00+09:00` | Absolute | with timezone offset |
| `30m 2026-03-15T12:00:00Z` | Absolute | datetime - 30 minutes |
| `2026-03-15T12:00:00Z +5h30m` | Absolute | datetime + 5h30m |
| `@10:30` | Absolute | today at 10:30 (time-of-day reset) |
| `@10:30+09:00` | Absolute | today at 10:30 JST |
| `@1704110400000` | Absolute | raw epoch ms (like `date -d @EPOCH`) |
| `3 minutes ago` | Relative | English-style modifier |

### TimeRange (`parse_range`)

Two-argument style (recommended):

| `since` | `until` | Description |
|---------|---------|-------------|
| `5m` | `3m` | last 5 min to last 3 min |
| `5m` | _(empty)_ | from 5 minutes ago |
| _(empty)_ | `3m` | until 3 minutes ago |
| `@5m` | `3m` | absolute since, relative until anchored to since |
| `5m` | `+3m` | explicit `+` for positive offset |

Tilde-delimited style (single string):

| `input` | Equivalent |
|---------|------------|
| `5m~3m` | since=`5m`, until=`3m` |
| `5d~` | since=`5d`, until=_(none)_ |
| `~3m` | since=_(none)_, until=`3m` |

### Timezone Offset (`parse_tz_offset`)

| Input | Result |
|-------|--------|
| `Z`, `UTC`, `GMT` | `Utc` |
| `9`, `+09`, `+09:00`, `+0900` | `Hour(9)` |
| `GMT+9`, `UTC+09:00` | `Hour(9)` |
| `+5:30`, `UTC+5:30` | `Min(330)` |
| `-5h`, `+9h30m` | duration-style offset |
| `local` | `Local` (resolved at runtime) |

## Re-serialization

`TimeSpec::to_cli_string()` preserves intent:

| Variant | Output | Use case |
|---------|--------|----------|
| Relative | `"-5m"`, `"+1h30m"` | Reproduces the same relative offset |
| Absolute | `"2026-03-15T12:00:00Z"` | Reproduces the exact point in time |

## Pluggable Design

All parse functions accept optional labeled parameters with sensible defaults:

- **`now`** — custom clock source (default: system time)
- **`epoch`** — custom epoch for Snowflake IDs, Performance API, etc.
- **`default_sign`** — `Minus` (for `--since`), `Plus`, or `Reject`
- **`default_tz_offset`** — timezone for TZ-less datetime inputs
- **`parse_datetime`** — replace ISO 8601 parser with locale-aware parser

## Multi-target

| Target | Local TZ | Notes |
|--------|----------|-------|
| Native | C FFI (`localtime_r`) | Full support |
| JS | `Date.getTimezoneOffset()` | Full support |
| WASM | Falls back to UTC | WASI has no TZ API |

## License

MIT License - Yoshiaki Kawazu (@kawaz)
