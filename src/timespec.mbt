/// Parses a single timespec string into a `TimeSpec`.
///
/// A timespec is a flexible time expression that may contain a datetime,
/// a duration, or both. The general syntax is:
///
/// ```
/// [@] [sign] (duration | datetime | time-of-day)+ [@]
/// ```
///
/// - `@` can appear anywhere (leading, trailing, or between segments) and
///   forces the result to be `Absolute`. Multiple `@` are allowed (idempotent).
/// - A datetime (e.g. `2025-03-15T00:00:00Z`) produces `Absolute`.
/// - A duration alone (e.g. `5m`) produces `Relative` (resolved from `now`).
/// - Duration segments adjacent to a datetime act as offsets on that datetime.
/// - `@HH:MM[:SS[.mmm]][TZ]` resets to today's time-of-day (requires `@`).
///
/// Multi-pass parsing phases:
/// 1. Extract duration segments (number + unit [+ ago])
/// 2. Detect `@` markers
/// 3. Detect time-of-day pattern (when `@` present)
/// 4. Parse remaining as datetime
/// 5. Build EpochTime
/// 6. Build TimeSpec
///
/// Parameters:
///
/// * `input` : The timespec string (e.g. `"5m"`, `"@5m"`, `"2025-01-01T00:00:00Z+1h"`).
/// * `epoch` : Base epoch offset subtracted from absolute results. Defaults to Unix epoch.
/// * `default_sign` : How to interpret unsigned durations. Defaults to `Plus`.
/// * `default_tz_offset` : Default timezone for TZ-less datetimes. Defaults to `Utc`.
/// * `now` : Clock function returning the current time in ms. Defaults to `@env.now`.
/// * `parse_datetime` : Pluggable datetime parser. Defaults to `default_parse_datetime`.
///
/// Returns `Some(TimeSpec)` for valid time expressions, or `None` for
/// explicit reset keywords (`none`, `null`, `nil`).
///
/// Raises `ParseError` on malformed input.
///|
pub fn parse_timespec(
  input : String,
  epoch~ : EpochTime = EpochTime(0L),
  default_sign~ : Sign = Plus,
  default_tz_offset~ : TzOffset = Local,
  now~ : () -> UInt64 = @env.now,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeSpec? raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty timespec string")
  }
  // Check for none/null/nil keywords (explicit reset)
  let lower = s.to_lower()
  if lower == "none" || lower == "null" || lower == "nil" {
    return None
  }
  // Check for "now" keyword
  let is_now = lower == "now" || lower == "@now" ||
    (lower.length() > 1 && {
      // Handle patterns like "@@now", "@@@now", etc.
      let mut all_at = true
      let mut i = 0
      while i < lower.length() - 3 {
        match lower.get_char(i) {
          Some('@') => i += 1
          _ => { all_at = false; break }
        }
      }
      all_at && lower[i:] == "now"
    })
  if is_now {
    let now_ms = now().reinterpret_as_int64()
    let epoch_time = EpochTime(now_ms - epoch.0)
    let has_at = s.to_lower().contains("@")
    if has_at {
      return Some(Absolute(epoch_time, Duration(0L)))
    } else {
      return Some(Relative(epoch_time, Duration(0L)))
    }
  }
  // ===== Phase 1: Leading sign + Duration segment extraction =====
  let mut pos = 0
  // Check for leading @
  let mut has_at = false
  match s.get_char(pos) {
    Some('@') => {
      has_at = true
      pos += 1
    }
    _ => ()
  }
  // Check for leading sign
  let mut needs_sign = false
  let mut leading_sign_char : Char? = None
  let negate : Bool = match s.get_char(pos) {
    Some('+') => {
      leading_sign_char = Some('+')
      pos += 1
      false
    }
    Some('-') => {
      leading_sign_char = Some('-')
      pos += 1
      true
    }
    _ =>
      match default_sign {
        Minus => true
        Plus => false
        Reject => {
          needs_sign = true
          false // Provisional value
        }
      }
  }
  pos = skip_spaces(s, pos)
  // Scan the string: accumulate duration segment ms directly, buffer non-duration parts
  let non_duration_buf = StringBuilder::new()
  let mut has_duration = false
  let mut total_duration_ms = 0L
  // Apply leading sign: negate applies to the first unsigned duration segment group
  // A segment group = consecutive duration segments delimited by explicit signs
  // The first group follows negate (leading sign); subsequent groups follow explicit signs
  let mut current_group_ms = 0L
  let mut current_group_sign : Int64 = if negate { -1L } else { 1L }
  let mut in_first_group = true // Whether we are still in the first group
  let mut scan_pos = pos
  while scan_pos < s.length() {
    scan_pos = skip_spaces(s, scan_pos)
    if scan_pos >= s.length() {
      break
    }
    match s.get_char(scan_pos) {
      Some('@') => {
        has_at = true
        non_duration_buf.write_char('@')
        scan_pos += 1
        continue
      }
      _ => ()
    }
    // Look ahead for a sign
    let seg_sign_start = scan_pos
    let mut seg_sign_char : Char? = None
    match s.get_char(scan_pos) {
      Some('+') => {
        seg_sign_char = Some('+')
        scan_pos += 1
      }
      Some('-') => {
        seg_sign_char = Some('-')
        scan_pos += 1
      }
      _ => ()
    }
    let after_sign = skip_spaces(s, scan_pos)
    // Check if it starts with a digit
    if is_digit_at(s, after_sign) {
      // Try as a duration segment candidate
      let probe_result = probe_duration_segment(s, after_sign)
      match probe_result {
        Some((seg_ms, is_ago, dur_end)) => {
          // Confirmed as a duration segment
          has_duration = true
          // Apply "ago" reversal
          let effective_ms = if is_ago { -seg_ms } else { seg_ms }
          match seg_sign_char {
            Some('+') => {
              // Explicit +: flush current group and start a new one
              if not(in_first_group) || has_duration {
                total_duration_ms = checked_add(
                  total_duration_ms,
                  checked_mul(current_group_sign, current_group_ms, msg="timespec overflow"),
                  msg="timespec overflow",
                )
              }
              current_group_ms = effective_ms
              current_group_sign = 1L
              in_first_group = false
            }
            Some('-') => {
              // Explicit -: flush current group and start a new one
              if not(in_first_group) || has_duration {
                total_duration_ms = checked_add(
                  total_duration_ms,
                  checked_mul(current_group_sign, current_group_ms, msg="timespec overflow"),
                  msg="timespec overflow",
                )
              }
              current_group_ms = effective_ms
              current_group_sign = -1L
              in_first_group = false
            }
            _ => {
              // No sign: accumulate into the current group
              current_group_ms = checked_add(
                current_group_ms, effective_ms, msg="timespec overflow",
              )
            }
          }
          scan_pos = dur_end
          continue
        }
        None => {
          // Not a duration segment -> non-duration
          scan_pos = seg_sign_start
          let non_dur_end = scan_non_duration(s, scan_pos)
          non_duration_buf.write_string(s[scan_pos:non_dur_end].to_string())
          scan_pos = non_dur_end
          continue
        }
      }
    } else {
      // Does not start with a digit -> non-duration
      scan_pos = seg_sign_start
      let non_dur_end = scan_non_duration(s, scan_pos)
      if non_dur_end == scan_pos {
        match s.get_char(scan_pos) {
          Some(c) => {
            non_duration_buf.write_char(c)
            scan_pos += 1
          }
          None => break
        }
      } else {
        non_duration_buf.write_string(s[scan_pos:non_dur_end].to_string())
        scan_pos = non_dur_end
      }
      continue
    }
  }
  // Flush the last group
  if has_duration {
    total_duration_ms = checked_add(
      total_duration_ms,
      checked_mul(current_group_sign, current_group_ms, msg="timespec overflow"),
      msg="timespec overflow",
    )
  }
  let duration = Duration(total_duration_ms)
  // ===== Phase 2: @ marker detection (has_at already set during scan) =====
  // ===== Phase 3: Time-of-day pattern detection =====
  let remaining_raw = non_duration_buf.to_string()
  let remaining_no_at = remaining_raw.replace(old="@", new="").trim().to_string()
  let mut time_of_day_ms : Int64? = None
  let mut tz_offset_timepart : TzOffset? = None
  let mut datetime_str : String = remaining_no_at
  if has_at && remaining_no_at.length() > 0 {
    let (dt_part, tod_part) = split_datetime_and_timeofday(remaining_no_at)
    datetime_str = dt_part
    if tod_part.length() > 0 {
      let (tod_epoch_ms, tod_tz) = parse_iso8601_with_tz(
        tod_part, default_tz_offset~,
      )
      time_of_day_ms = Some(tod_epoch_ms)
      tz_offset_timepart = tod_tz
    }
  }
  // ===== Phase 3.5: Raw epoch ms detection =====
  // With @ and remaining string is [+-]?digits only -> raw epoch ms (date -d @EPOCH convention)
  // Restore leading sign consumed in Phase 1
  let mut has_raw_epoch = false
  let mut raw_epoch_ms = 0L
  let raw_candidate = if datetime_str.length() > 0 && not(has_duration) {
    match leading_sign_char {
      Some(c) => c.to_string() + datetime_str
      None => datetime_str
    }
  } else {
    datetime_str
  }
  if has_at && raw_candidate.length() > 0 && is_signed_digits(raw_candidate) {
    raw_epoch_ms = parse_raw_epoch(raw_candidate)
    has_raw_epoch = true
    datetime_str = ""
  }
  // ===== Phase 4: Datetime parsing =====
  let mut has_datetime = false
  let mut dt_epoch_ms = 0L
  let mut tz_offset_datetime : TzOffset? = None
  if datetime_str.length() > 0 {
    match parse_datetime(datetime_str) {
      Some(epoch_ms) => {
        has_datetime = true
        dt_epoch_ms = epoch_ms
        // Detect TzOffset from the string suffix independently (parser-agnostic)
        tz_offset_datetime = detect_tz_suffix(datetime_str)
      }
      None =>
        raise ParseError(
          "failed to parse datetime: " + datetime_str + " in: " + input,
        )
    }
  }
  // ===== Phase 5: Build EpochTime =====
  // `@` alone with no duration/datetime/time-of-day → Absolute(now)
  if has_at && not(has_duration) && not(has_datetime) && not(has_raw_epoch) && time_of_day_ms is None {
    let now_ms = now().reinterpret_as_int64()
    return Some(Absolute(EpochTime(now_ms - epoch.0), Duration(0L)))
  }
  if not(has_duration) && not(has_datetime) && not(has_raw_epoch) && time_of_day_ms is None && not(has_at) {
    raise ParseError("no duration or datetime found in: " + input)
  }
  // Reject mode check: duration only with no datetime/time-of-day/raw epoch
  if needs_sign && not(has_datetime) && not(has_raw_epoch) && time_of_day_ms is None {
    raise ParseError("missing sign in timespec: " + input)
  }
  // Determine the base epoch_ms
  let mut base_epoch_ms = 0L
  if has_raw_epoch {
    base_epoch_ms = raw_epoch_ms
  } else if has_datetime {
    base_epoch_ms = dt_epoch_ms
  } else {
    base_epoch_ms = now().reinterpret_as_int64()
  }
  // Time-of-day reset
  match time_of_day_ms {
    Some(tod_ms) => {
      // TzOffset consistency check
      let effective_tod_tz = match tz_offset_timepart {
        Some(tz) => tz
        None => default_tz_offset
      }
      let effective_dt_tz = match tz_offset_datetime {
        Some(tz) => tz
        None => default_tz_offset
      }
      if has_datetime {
        if not(effective_tod_tz.equal_offset(effective_dt_tz)) {
          raise ParseError("ambiguous timezone offset")
        }
      }
      // Truncate base to local midnight
      let offset_minutes = tz_offset_to_minutes(effective_tod_tz)
      let offset_ms = offset_minutes.to_int64() * 60_000L
      let local_ms = base_epoch_ms + offset_ms
      let local_midnight = local_ms - floor_mod_i64(local_ms, 86_400_000L)
      let utc_midnight = local_midnight - offset_ms
      base_epoch_ms = utc_midnight + tod_ms
    }
    None => ()
  }
  // Add duration
  let final_epoch_ms = checked_add(
    base_epoch_ms - epoch.0, duration.0, msg="timespec overflow",
  )
  // ===== Phase 6: Build TimeSpec =====
  let epoch_time = EpochTime(final_epoch_ms)
  if has_at || has_datetime {
    Some(Absolute(epoch_time, duration))
  } else {
    Some(Relative(epoch_time, duration))
  }
}

/// Probes whether a duration segment (number + unit [+ ago]) starts at `pos`.
///
/// Returns `Some((ms_value, is_ago, end_pos))` if a valid duration segment is found,
/// or `None` if the number is not followed by a duration unit.
/// The returned `ms_value` is always positive; `is_ago` indicates the `ago` modifier.
///|
fn probe_duration_segment(
  s : StringView,
  pos : Int
) -> (Int64, Bool, Int)? raise ParseError {
  // Read the digit part
  let mut p = pos
  while p < s.length() {
    match s.get_char(p) {
      Some(c) =>
        if c.is_ascii_digit() || c == '_' || c == '.' {
          p += 1
        } else {
          break
        }
      None => break
    }
  }
  if p == pos {
    return None
  }
  let after_num = skip_spaces(s, p)
  // Check if a unit character follows
  let unit_result = try {
    parse_unit(s, after_num)
  } catch {
    _ => (0L, after_num)
  }
  let (ms_mul, unit_end) = unit_result
  if unit_end == after_num {
    return None // No unit found -> not a duration
  }
  // Actually parse the numeric value
  let (integer_part, fractional_part, _) = parse_number(s, pos)
  // Compute ms
  let mut seg_ms = checked_mul(integer_part, ms_mul, msg="timespec overflow")
  if fractional_part > 0.0 {
    let frac_ms = (fractional_part * ms_mul.to_double()).to_int64()
    seg_ms = checked_add(seg_ms, frac_ms, msg="timespec overflow")
  }
  // Check for "ago" modifier
  let after_unit = skip_spaces(s, unit_end)
  let (is_ago, end) = if try_match_word(s, after_unit, "ago") {
    (true, after_unit + 3)
  } else {
    (false, unit_end)
  }
  Some((seg_ms, is_ago, end))
}

/// Scans forward from `pos` collecting non-duration characters.
///
/// Stops at: whitespace, `@`, or a position where a `[+-]?digit+unit` pattern
/// could start (potential duration segment boundary).
///|
fn scan_non_duration(s : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < s.length() {
    match s.get_char(pos) {
      Some(' ') | Some('\t') => break
      Some('@') => break
      Some('+') | Some('-') => {
        let after_sign = pos + 1
        if is_digit_at(s, after_sign) {
          let probe = try { probe_duration_segment(s, after_sign) } catch { _ => None }
          match probe {
            Some(_) => break
            None => pos += 1
          }
        } else {
          pos += 1
        }
      }
      Some(c) =>
        if c.is_ascii_digit() {
          let probe = try { probe_duration_segment(s, pos) } catch { _ => None }
          match probe {
            Some(_) => break
            None => pos += 1
          }
        } else {
          pos += 1
        }
      None => break
    }
  }
  pos
}

/// Splits a string into datetime and time-of-day parts.
///
/// If the string contains a 4-digit year pattern (YYYY followed by `-` or `/`),
/// it's treated as datetime. Otherwise, if it looks like a time pattern (contains `:`),
/// it's treated as time-of-day.
///|
fn split_datetime_and_timeofday(s : String) -> (String, String) {
  let sv : StringView = s
  // Search for a 4-digit year pattern
  let mut dt_start = -1
  let mut i = 0
  while i < sv.length() {
    if is_four_digits_at_sv(sv, i) {
      match sv.get_char(i + 4) {
        Some('-') | Some('/') => {
          dt_start = i
          break
        }
        _ => ()
      }
    }
    i += 1
  }
  if dt_start >= 0 {
    // Find the end of the datetime part
    let dt_end = find_datetime_end_sv(sv, dt_start)
    let dt_part = sv[dt_start:dt_end].to_string().trim().to_string()
    // Check if there is a time-of-day in non-datetime parts
    let before = sv[0:dt_start].to_string().trim().to_string()
    let after : String = if dt_end < sv.length() {
      sv[dt_end:sv.length()].to_string().trim().to_string()
    } else {
      ""
    }
    let tod : String = if before.contains(":") {
      before
    } else if after.contains(":") {
      after
    } else {
      ""
    }
    (dt_part, tod)
  } else {
    if s.contains(":") {
      ("", s)
    } else {
      (s, "")
    }
  }
}

/// Checks whether four consecutive ASCII digits exist starting at `pos` in a StringView.
///|
fn is_four_digits_at_sv(s : StringView, pos : Int) -> Bool {
  if pos + 4 > s.length() {
    return false
  }
  for i in 0..<4 {
    match s.get_char(pos + i) {
      Some(c) => if not(c.is_ascii_digit()) { return false }
      None => return false
    }
  }
  true
}

/// Finds the end of a datetime pattern starting at `start`.
/// Consumes digits, separators, T, colon, dot, Z, and timezone offset.
///|
fn find_datetime_end_sv(s : StringView, start : Int) -> Int {
  let mut pos = start
  let mut after_t = false
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if c.is_ascii_digit() ||
          c == '-' ||
          c == '/' ||
          c == 'T' ||
          c == 't' ||
          c == ':' ||
          c == '.' ||
          c == 'Z' ||
          c == 'z' ||
          c == ' ' {
          if c == 'T' || c == 't' {
            after_t = true
          }
          // space: may act as T separator in datetime. End if next char is not a digit
          if c == ' ' {
            if not(is_digit_at(s, pos + 1)) {
              break
            }
          }
          pos += 1
        } else if (c == '+' || c == '-') && after_t {
          let tz_end = probe_tz_offset_sv(s, pos)
          if tz_end > pos {
            pos = tz_end
          } else {
            break
          }
        } else {
          break
        }
      None => break
    }
  }
  pos
}

/// Probes whether a +/- at sign_pos is a timezone offset.
/// Returns end position if TZ offset, or sign_pos if duration sign.
///|
fn probe_tz_offset_sv(s : StringView, sign_pos : Int) -> Int {
  let mut pos = sign_pos + 1
  let digit_start = pos
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if c.is_ascii_digit() {
          pos += 1
        } else {
          break
        }
      None => break
    }
  }
  let digit_count = pos - digit_start
  if digit_count == 0 {
    return sign_pos
  }
  match s.get_char(pos) {
    Some('h') | Some('s') | Some('w') | Some('d') => return sign_pos
    Some('m') =>
      match s.get_char(pos + 1) {
        Some('s') => return sign_pos
        Some(c) =>
          if not(c.is_ascii_digit()) {
            return sign_pos
          }
        None => return sign_pos
      }
    Some('u') | Some('n') | Some('\u03BC') => return sign_pos
    _ => ()
  }
  match s.get_char(pos) {
    Some(':') => {
      pos += 1
      while pos < s.length() {
        match s.get_char(pos) {
          Some(c) =>
            if c.is_ascii_digit() {
              pos += 1
            } else {
              break
            }
          None => break
        }
      }
    }
    _ => ()
  }
  pos
}

/// Compares two `TzOffset` values for equality by their resolved UTC offset in minutes.
///
/// `Local` is resolved to the system timezone before comparison.
/// For example, `Hour(0)` and `Utc` are considered equal since both resolve to 0 minutes.
///|
pub fn TzOffset::equal_offset(self : TzOffset, other : TzOffset) -> Bool {
  tz_offset_to_minutes(self) == tz_offset_to_minutes(other)
}

/// Floor modulo for Int64 that always returns a non-negative result.
///|
fn floor_mod_i64(a : Int64, b : Int64) -> Int64 {
  let r = a % b
  if r < 0L {
    r + b
  } else {
    r
  }
}

/// Checks if a string is [+-]?[0-9]+ (optional sign followed by digits only).
///|
fn is_signed_digits(s : String) -> Bool {
  let sv : StringView = s
  if sv.length() == 0 {
    return false
  }
  let mut i = 0
  // Skip leading sign
  match sv.get_char(0) {
    Some('+') | Some('-') => i = 1
    _ => ()
  }
  if i >= sv.length() {
    return false // Sign only
  }
  while i < sv.length() {
    match sv.get_char(i) {
      Some(c) => if not(c.is_ascii_digit()) { return false }
      None => return false
    }
    i += 1
  }
  true
}

/// Parses a signed digit string as raw epoch milliseconds.
///|
fn parse_raw_epoch(s : String) -> Int64 raise ParseError {
  let sv : StringView = s
  let mut i = 0
  let mut neg = false
  match sv.get_char(0) {
    Some('+') => i = 1
    Some('-') => {
      neg = true
      i = 1
    }
    _ => ()
  }
  let mut value = 0L
  let max_div = 922_337_203_685_477_580L // Int64::max_value / 10
  let max_mod = 7 // Int64::max_value % 10
  while i < sv.length() {
    match sv.get_char(i) {
      Some(c) => {
        let digit = c.to_int() - '0'.to_int()
        if value > max_div || (value == max_div && digit > max_mod) {
          raise ParseError("epoch value too large: " + s)
        }
        value = value * 10L + digit.to_int64()
        i += 1
      }
      None => break
    }
  }
  if neg { -value } else { value }
}
