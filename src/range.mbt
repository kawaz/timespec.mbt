/// Recalculates a `Relative` TimeSpec's epoch using `anchor_epoch` as the base
/// instead of `now`. `Absolute` timespecs are returned unchanged.
///|
fn resolve_relative_with_anchor(
  ts : TimeSpec,
  anchor_epoch : Int64
) -> TimeSpec {
  match ts {
    Absolute(_, _) => ts // Absolute remains unchanged
    Relative(_, duration) => {
      let duration_ms = duration.0
      let new_epoch = anchor_epoch + duration_ms
      Relative(EpochTime(new_epoch), duration)
    }
  }
}

/// Parses a time range with optional `since` and `until` bounds.
///
/// Supports three input styles:
///
/// 1. **Two-argument** (recommended): pass `since` and/or `until` individually.
/// 2. **Tilde notation**: pass `input` as a tilde-delimited `"since~until"` string (e.g. `"5d~3m"`, `"5d~"`, `"~3m"`).
/// 3. **Mixed**: explicit `since`/`until` override values derived from `input`.
///
/// Parameters:
///
/// * `input` : A tilde-delimited range string. Split on tilde (`~`) to derive since/until.
/// * `since` : The since-side timespec string. Overrides `input` when non-empty.
/// * `until` : The until-side timespec string. Overrides `input` when non-empty.
/// * `epoch` : Base epoch offset. Defaults to Unix epoch.
/// * `default_sign` : Sign interpretation for unsigned durations. Defaults to `Plus`.
/// * `now` : Clock function. Defaults to `@env.now`.
/// * `default_tz_offset` : Default timezone for TZ-less datetimes. Defaults to `Utc`.
/// * `swap` : When `true`, swaps since/until if since > until. Defaults to `false`.
/// * `parse_datetime` : Pluggable datetime parser. Defaults to `default_parse_datetime`.
///
/// Returns a `TimeRange` with anchor resolution applied when one side is
/// `Absolute` and the other is `Relative`.
///|
pub fn parse_range(
  input~ : String = "",
  since~ : String = "",
  until~ : String = "",
  epoch~ : EpochTime = EpochTime(0L),
  default_sign~ : Sign = Plus,
  default_tz_offset~ : TzOffset = Local,
  now~ : () -> UInt64 = @env.now,
  swap~ : Bool = false,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeRange raise ParseError {
  // Mutual exclusion check between input and since/until
  let mut since = since
  let mut until = until
  if input.length() > 0 && (since.length() > 0 || until.length() > 0) {
    raise ParseError(
      "cannot specify both input and since/until in parse_range",
    )
  }
  // Expand since/until from input
  if input.length() > 0 {
    match input.split_once("~") {
      Some((s, u)) => {
        since = s.to_string()
        until = u.to_string()
      }
      None => since = input // No tilde -> treat as since
    }
  }
  // Parse since (if non-empty)
  let mut since_ts : TimeSpec? = if since.trim().length() > 0 {
    parse_timespec(
      since, epoch~, default_sign~, default_tz_offset~, now~, parse_datetime~,
    )
  } else {
    None
  }
  // Parse until (if non-empty)
  let mut until_ts : TimeSpec? = if until.trim().length() > 0 {
    parse_timespec(
      until, epoch~, default_sign~, default_tz_offset~, now~, parse_datetime~,
    )
  } else {
    None
  }
  // Anchor resolution (only when both are present)
  match (since_ts, until_ts) {
    (Some(s), Some(u)) => {
      let (resolved_s, resolved_u) = resolve_anchor(s, u)
      since_ts = Some(resolved_s)
      until_ts = Some(resolved_u)
    }
    _ => ()
  }
  // swap: exchange since and until if since > until
  if swap {
    match (since_ts, until_ts) {
      (Some(s), Some(u)) =>
        if s.to_epoch_ms() > u.to_epoch_ms() {
          let tmp = since_ts
          since_ts = until_ts
          until_ts = tmp
        }
      _ => ()
    }
  }
  { since: since_ts, until: until_ts }
}

/// Resolves anchor relationships between since and until TimeSpecs.
///
/// When one side is `Absolute` and the other is `Relative`, the absolute side
/// becomes the anchor and the relative side is recalculated against it.
/// When both are the same kind, they remain independently resolved.
///|
fn resolve_anchor(
  since_ts : TimeSpec,
  until_ts : TimeSpec
) -> (TimeSpec, TimeSpec) {
  let s_abs = since_ts.is_absolute()
  let u_abs = until_ts.is_absolute()
  if s_abs && not(u_abs) {
    // since is Absolute -> recalculate until relative to since
    let resolved = resolve_relative_with_anchor(
      until_ts, since_ts.to_epoch_ms(),
    )
    (since_ts, resolved)
  } else if u_abs && not(s_abs) {
    // until is Absolute -> recalculate since relative to until
    let resolved = resolve_relative_with_anchor(
      since_ts, until_ts.to_epoch_ms(),
    )
    (resolved, until_ts)
  } else {
    // Same kind -> independent
    (since_ts, until_ts)
  }
}
