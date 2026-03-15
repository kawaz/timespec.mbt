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

## Features

- **Duration parsing**: `5m`, `1.5h`, `3_600_000ms`, `1h30m45s`, `3 minutes ago`
- **Unit aliases**: `hour`/`hours`/`hr`, `minute`/`minutes`/`min`, `second`/`seconds`/`sec`, etc.
- **TimeSpec**: duration + datetime interleaving, `@` for absolute pinning
- **Time-of-day reset**: `@00:00` (today's midnight), `@10:30` (today at 10:30)
- **Raw epoch**: `@1704110400000` (direct epoch ms, like `date -d @EPOCH`)
- **TimeRange**: `since~`/`until~` two-argument or `input~` tilde notation
- **Timezone offset**: `parse_tz_offset("GMT+9")`, `local_tz_offset()`
- **ISO 8601**: lenient parsing with date normalization, partial dates (`2026`, `2026-03`), time-only (`10:30`)
- **Re-serialization**: `to_cli_string()` preserves Absolute/Relative intent
- **Pluggable**: custom `now~`, `parse_datetime~`, `epoch~`, `default_tz_offset~`
- **Custom epoch**: Snowflake, Performance API, etc.
- **Multi-target**: JS, Native (with C FFI for local TZ), WASM

## Types

```moonbit
pub(all) struct Duration(Int64)      // milliseconds
pub(all) struct EpochTime(Int64)     // milliseconds from epoch

pub(all) enum TimeSpec {
  Absolute(EpochTime, Duration)      // pinned time + offset
  Relative(EpochTime, Duration)      // relative time + offset
}

pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
}

pub(all) enum TzOffset { Utc; Local; Hour(Int); Min(Int) }
pub(all) enum Sign { Minus; Plus; Reject }
```

## Duration Constants

```moonbit
@timespec.millisecond  // Duration(1)
@timespec.second       // Duration(1000)
@timespec.minute       // Duration(60000)
@timespec.hour         // Duration(3600000)
@timespec.day          // Duration(86400000)
@timespec.week         // Duration(604800000)
```

## License

MIT License - Yoshiaki Kawazu (@kawaz)
