/// A duration representing a span of time in milliseconds.
///
/// The inner `Int64` value holds the number of milliseconds. Negative values
/// represent durations in the past direction.
///
/// Supports arithmetic via `Add`, `Sub`, and `Neg` trait implementations,
/// as well as scalar multiplication via `Duration::scale`.
///|
pub(all) struct Duration(Int64) derive(Eq, Show, Compare)

/// A point in time represented as milliseconds elapsed since the epoch.
///
/// Unlike `Duration` which represents a span of time, `EpochTime` represents
/// a specific instant. The epoch is Unix epoch (1970-01-01T00:00:00Z) by default,
/// but can be shifted via the `epoch~` parameter in parse functions.
///|
pub(all) struct EpochTime(Int64) derive(Eq, Show, Compare)

/// A parsed time specification, either absolute or relative.
///
/// Both variants carry `(EpochTime, Duration)`. The difference lies in
/// re-serialization behavior via `to_cli_string`:
///
/// - `Absolute` serializes to an ISO 8601 datetime string (e.g. `2025-03-15T00:56:14Z`).
///   The result is reproducible regardless of when or by whom it is executed.
/// - `Relative` serializes to a signed duration string (e.g. `-8m`, `+1h30m`).
///   The resolved time changes with each execution.
///
/// The `Duration` field preserves the original offset information for re-serialization.
/// For datetime-only inputs, the `Duration` is `Duration(0L)`.
///|
pub(all) enum TimeSpec {
  Absolute(EpochTime, Duration)
  Relative(EpochTime, Duration)
} derive(Eq, Show)

/// Returns the resolved epoch time.
///|
pub fn TimeSpec::epoch(self : TimeSpec) -> EpochTime {
  match self {
    Absolute(e, _) | Relative(e, _) => e
  }
}

/// Returns the duration offset used to compute the epoch time.
///|
pub fn TimeSpec::duration(self : TimeSpec) -> Duration {
  match self {
    Absolute(_, d) | Relative(_, d) => d
  }
}

/// Returns whether this is an absolute time specification.
///|
pub fn TimeSpec::is_absolute(self : TimeSpec) -> Bool {
  match self {
    Absolute(_, _) => true
    Relative(_, _) => false
  }
}

/// A time range consisting of optional `since` and `until` bounds.
///
/// Either or both fields may be `None` to represent an open-ended range.
/// When both are present and one is `Absolute` while the other is `Relative`,
/// the absolute side serves as an anchor for resolving the relative side.
///|
pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
} derive(Eq, Show)

/// Controls how unsigned (no explicit `+` or `-`) duration inputs are interpreted.
///
/// Passed as the `default_sign~` parameter to parse functions. The caller
/// chooses the variant based on application context:
///
/// - `Minus` — unsigned means negative (e.g. `--since 5m` means "5 minutes ago").
/// - `Plus` — unsigned means positive (e.g. `set_timer("3m")` means "3 minutes from now").
/// - `Reject` — unsigned is an error; an explicit sign is required to avoid ambiguity.
///|
pub(all) enum Sign {
  Minus
  Plus
  Reject
} derive(Eq, Show)

/// A timezone offset from UTC.
///
/// - `Utc` — zero offset (serialized as `Z`).
/// - `Local` — resolved at runtime to the system's local timezone offset.
/// - `Hour(n)` — offset in whole hours (e.g. `Hour(9)` for `+09:00`).
/// - `Min(n)` — offset in minutes for non-whole-hour zones (e.g. `Min(330)` for `+05:30`).
///|
pub(all) enum TzOffset {
  Utc
  Local
  Hour(Int)
  Min(Int)
} derive(Eq, Show)

/// Error type raised when parsing fails.
///
/// Contains a human-readable message describing the parse failure.
///|
pub(all) suberror ParseError {
  ParseError(String)
} derive(Eq, Show)

