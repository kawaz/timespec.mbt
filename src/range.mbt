/// Recalculates a `Relative` TimeSpec's epoch using `anchor_epoch` as the base
/// instead of `now`. `Absolute` timespecs are returned unchanged.
///|
fn resolve_relative_with_anchor(
  ts : TimeSpec,
  anchor_epoch : Int64
) -> TimeSpec {
  match ts {
    Absolute(_, _) => ts // 絶対は変更しない
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
/// 1. **Two-argument** (recommended): pass `since~` and/or `until~` individually.
/// 2. **Tilde notation**: pass `input~` as `"since~until"` (e.g. `"5d~3m"`, `"5d~"`, `"~3m"`).
/// 3. **Mixed**: explicit `since~`/`until~` override values derived from `input~`.
///
/// Parameters:
///
/// * `input~` : A tilde-separated range string. Split on `~` to derive since/until.
/// * `since~` : The since-side timespec string. Overrides `input~` when non-empty.
/// * `until~` : The until-side timespec string. Overrides `input~` when non-empty.
/// * `epoch~` : Base epoch offset. Defaults to Unix epoch.
/// * `default_sign~` : Sign interpretation for unsigned durations. Defaults to `Plus`.
/// * `now~` : Clock function. Defaults to `@env.now`.
/// * `default_tz_offset~` : Default timezone for TZ-less datetimes. Defaults to `Utc`.
/// * `swap~` : When `true`, swaps since/until if since > until. Defaults to `false`.
/// * `parse_datetime~` : Pluggable datetime parser. Defaults to `default_parse_datetime`.
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
  // input~ と since~/until~ の排他チェック
  let mut since = since
  let mut until = until
  if input.length() > 0 && (since.length() > 0 || until.length() > 0) {
    raise ParseError(
      "cannot specify both input~ and since~/until~ in parse_range",
    )
  }
  // input~ から since/until を展開
  if input.length() > 0 {
    match input.split_once("~") {
      Some((s, u)) => {
        since = s.to_string()
        until = u.to_string()
      }
      None => since = input // ~ なし → since として扱う
    }
  }
  // since をパース（空でなければ）
  let mut since_ts : TimeSpec? = if since.trim().length() > 0 {
    Some(
      parse_timespec(
        since, epoch~, default_sign~, default_tz_offset~, now~, parse_datetime~,
      ),
    )
  } else {
    None
  }
  // until をパース（空でなければ）
  let mut until_ts : TimeSpec? = if until.trim().length() > 0 {
    Some(
      parse_timespec(
        until, epoch~, default_sign~, default_tz_offset~, now~, parse_datetime~,
      ),
    )
  } else {
    None
  }
  // アンカー解決（両方ある場合のみ）
  match (since_ts, until_ts) {
    (Some(s), Some(u)) => {
      let (resolved_s, resolved_u) = resolve_anchor(s, u)
      since_ts = Some(resolved_s)
      until_ts = Some(resolved_u)
    }
    _ => ()
  }
  // swap: since > until なら入れ替え
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
    // since が Absolute → until を since 基準で再計算
    let resolved = resolve_relative_with_anchor(
      until_ts, since_ts.to_epoch_ms(),
    )
    (since_ts, resolved)
  } else if u_abs && not(s_abs) {
    // until が Absolute → since を until 基準で再計算
    let resolved = resolve_relative_with_anchor(
      since_ts, until_ts.to_epoch_ms(),
    )
    (resolved, until_ts)
  } else {
    // 同種 → 独立
    (since_ts, until_ts)
  }
}
