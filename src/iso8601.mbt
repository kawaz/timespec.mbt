/// Parses an ISO 8601 datetime string and returns the epoch time in milliseconds.
///
/// This is the default `parse_datetime` implementation used by `parse_timespec`.
/// It can be replaced with a custom parser via the `parse_datetime` parameter.
///
/// Accepted formats include `YYYY-MM-DD`, `YYYY-MM-DDTHH:MM:SS`,
/// `YYYY-MM-DDTHH:MM:SS.sssZ`, and `YYYY-MM-DDTHH:MM:SS+HH:MM`.
/// The `/` separator is also accepted in place of `-`.
/// Inputs without timezone information are interpreted as UTC.
///
/// Parameters:
///
/// * `input` : The datetime string to parse.
///
/// Returns `Some(epoch_ms)` on success, or `None` if parsing fails.
///|
pub fn default_parse_datetime(input : String) -> Int64? {
  try {
    Some(parse_iso8601(input))
  } catch {
    _ => None
  }
}

/// Creates a `parse_datetime` function that interprets TZ-less datetimes
/// with the given default timezone offset.
///
/// ```
/// let parse_jst = make_parse_datetime(default_tz_offset=Hour(9))
/// parse_timespec("2026-03-15T12:00:00", parse_datetime=parse_jst)
/// ```
///|
pub fn make_parse_datetime(
  default_tz_offset~ : TzOffset = Local
) -> (String) -> Int64? {
  fn(input) {
    try {
      Some(parse_iso8601(input, default_tz_offset~))
    } catch {
      _ => None
    }
  }
}

/// Parses an ISO 8601 datetime string and returns the epoch time in milliseconds
/// along with the parsed timezone offset (if explicitly present in the input).
///
/// Handles date, time, fractional seconds, and timezone offset components.
/// Also supports time-only inputs like `HH:MM[:SS[.mmm]][TZ]` (assumed 1970-01-01).
/// Raises `ParseError` on malformed input.
///
/// Returns `(epoch_ms, Some(tz))` when the input has an explicit timezone,
/// or `(epoch_ms, None)` when `default_tz_offset` was used as fallback.
///|
fn parse_iso8601_with_tz(
  input : String,
  default_tz_offset~ : TzOffset = Local
) -> (Int64, TzOffset?) raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty datetime string")
  }
  let mut pos = 0
  // 先頭が4桁年かチェック
  let is_time_only = not(is_four_digits_at_sv(s, 0))
  let mut year = 1970
  let mut month = 1
  let mut day = 1
  if is_time_only {
    // time-only: 直接 HH:MM をパース（T セパレータ不要）
    // 時(1-2桁)
    let (h, p4) = parse_int_digits(s, pos, 1, 2)
    pos = p4
    // ':' が必須（time-only の判定根拠）
    match s.get_char(pos) {
      Some(':') => pos += 1
      _ =>
        raise ParseError(
          "expected ':' at position " + pos.to_string() + " in: " + input,
        )
    }
    let (mi, p5) = parse_int_digits(s, pos, 1, 2)
    pos = p5
    let hour = h
    let min = mi
    let mut sec = 0
    let mut ms = 0
    // 秒（省略可）
    if pos < s.length() {
      match s.get_char(pos) {
        Some(':') => {
          pos += 1
          let (sc, p6) = parse_int_digits(s, pos, 1, 2)
          sec = sc
          pos = p6
        }
        _ => ()
      }
    }
    // ミリ秒（オプション）
    match s.get_char(pos) {
      Some('.') => {
        pos += 1
        let (frac, frac_digits, p7) = parse_frac_digits(s, pos, 3)
        ms = frac
        let mut scale = frac_digits
        while scale < 3 {
          ms *= 10
          scale += 1
        }
        pos = p7
      }
      _ => ()
    }
    // タイムゾーンオフセット（オプション）
    let (has_tz, tz_offset_min, new_pos) = parse_tz_suffix(s, pos)
    pos = new_pos
    // 末尾に余分な文字がないか確認
    if pos < s.length() {
      raise ParseError(
        "unexpected character at position " + pos.to_string() + " in: " + input,
      )
    }
    let (tz, parsed_tz) = resolve_tz(has_tz, tz_offset_min, default_tz_offset)
    let epoch = datetime_to_epoch(
      year, month, day, hour, min, sec, ms, tz_offset=tz,
    )
    return (epoch, parsed_tz)
  }
  // 年(4桁)
  let (yr, p1) = parse_int_digits(s, pos, 4, 4)
  year = yr
  pos = p1
  // 月（必須 — 部分日付は曖昧さ排除のため拒否）
  let has_date_sep = match s.get_char(pos) {
    Some('-') | Some('/') => true
    _ => false
  }
  if not(has_date_sep) && not(is_digit_at(s, pos)) {
    raise ParseError("incomplete date (year-only): " + input)
  }
  pos = skip_date_sep(s, pos)
  let (m, p2) = parse_int_digits(s, pos, 1, 2)
  month = m
  pos = p2
  // 日（必須）
  if not(match s.get_char(pos) {
    Some('-') | Some('/') => true
    _ => is_digit_at(s, pos) && not(has_date_sep)
  }) {
    raise ParseError("incomplete date (year-month only): " + input)
  }
  pos = skip_date_sep(s, pos)
  let (d, p3) = parse_int_digits(s, pos, 1, 2)
  day = d
  pos = p3
  // 時分秒（オプション）
  let mut hour = 0
  let mut min = 0
  let mut sec = 0
  let mut ms = 0
  if pos < s.length() {
    match s.get_char(pos) {
      Some('T') | Some('t') | Some(' ') => {
        pos += 1
        // 時(1-2桁)
        let (h, p4) = parse_int_digits(s, pos, 1, 2)
        hour = h
        pos = p4
        // 分（省略可）
        let has_time_sep = match s.get_char(pos) {
          Some(':') => true
          _ => false
        }
        if pos < s.length() && (has_time_sep || is_digit_at(s, pos)) {
          pos = skip_time_sep(s, pos)
          let (m, p5) = parse_int_digits(s, pos, 1, 2)
          min = m
          pos = p5
          // 秒（省略可）
          if pos < s.length() && (match s.get_char(pos) {
            Some(':') => true
            _ => is_digit_at(s, pos) && not(has_time_sep)
          }) {
            pos = skip_time_sep(s, pos)
            let (sc, p6) = parse_int_digits(s, pos, 1, 2)
            sec = sc
            pos = p6
          }
        }
        // ミリ秒（オプション）
        match s.get_char(pos) {
          Some('.') => {
            pos += 1
            let (frac, frac_digits, p7) = parse_frac_digits(s, pos, 3)
            ms = frac
            // 桁数が足りなければゼロ埋め
            let mut scale = frac_digits
            while scale < 3 {
              ms *= 10
              scale += 1
            }
            pos = p7
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  // タイムゾーンオフセット（オプション）
  let (has_tz, tz_offset_min, new_pos) = parse_tz_suffix(s, pos)
  pos = new_pos
  // 末尾に余分な文字がないか確認
  if pos < s.length() {
    raise ParseError(
      "unexpected character at position " + pos.to_string() + " in: " + input,
    )
  }
  let (tz, parsed_tz) = resolve_tz(has_tz, tz_offset_min, default_tz_offset)
  let epoch = datetime_to_epoch(year, month, day, hour, min, sec, ms, tz_offset=tz)
  (epoch, parsed_tz)
}

/// Detects a timezone suffix at the end of a datetime string.
///
/// Recognizes trailing `Z`/`z`, `+HH:MM`/`-HH:MM`, and `+HHMM`/`-HHMM`.
/// Returns `Some(tz)` if an explicit timezone is found, `None` otherwise.
///
/// This is independent of the datetime parser, so it works with any format
/// (ISO 8601, locale-specific, etc.) as long as the TZ suffix follows
/// standard notation.
///|
fn detect_tz_suffix(input : String) -> TzOffset? {
  let s : StringView = input
  let len = s.length()
  if len == 0 {
    return None
  }
  // Pattern 1: trailing Z/z
  match s.get_char(len - 1) {
    Some('Z') | Some('z') => return Some(Utc)
    _ => ()
  }
  // Pattern 2: +/-HH:MM (6 chars: sign + 2 digits + colon + 2 digits)
  if len >= 6 {
    let p = len - 6
    let is_sign = match s.get_char(p) {
      Some('+') | Some('-') => true
      _ => false
    }
    let has_colon = match s.get_char(p + 3) {
      Some(':') => true
      _ => false
    }
    if is_sign && has_colon && is_digit_at(s, p + 1) && is_digit_at(s, p + 2) &&
      is_digit_at(s, p + 4) && is_digit_at(s, p + 5) {
      let sign = match s.get_char(p) {
        Some('-') => -1
        _ => 1
      }
      let hh = digit_value_at(s, p + 1) * 10 + digit_value_at(s, p + 2)
      let mm = digit_value_at(s, p + 4) * 10 + digit_value_at(s, p + 5)
      return Some(normalize_tz_offset(sign * (hh * 60 + mm)))
    }
  }
  // Pattern 3: +/-HHMM (5 chars: sign + 4 digits)
  if len >= 5 {
    let p = len - 5
    let is_sign = match s.get_char(p) {
      Some('+') | Some('-') => true
      _ => false
    }
    if is_sign && is_digit_at(s, p + 1) && is_digit_at(s, p + 2) &&
      is_digit_at(s, p + 3) && is_digit_at(s, p + 4) {
      let sign = match s.get_char(p) {
        Some('-') => -1
        _ => 1
      }
      let hh = digit_value_at(s, p + 1) * 10 + digit_value_at(s, p + 2)
      let mm = digit_value_at(s, p + 3) * 10 + digit_value_at(s, p + 4)
      return Some(normalize_tz_offset(sign * (hh * 60 + mm)))
    }
  }
  // Pattern 4: +/-HH or +/-H (2-3 chars: sign + 1-2 digits)
  // Safe because partial dates (YYYY, YYYY-MM) are rejected by the parser.
  // The sign must be preceded by a digit (time component) to avoid matching
  // date separators like the '-' in "2024-01-15".
  for offset in [3, 2] {
    if len >= offset {
      let p = len - offset
      match s.get_char(p) {
        Some('+') | Some('-') => {
          // Check all chars after sign are digits
          let mut all_digits = true
          for i in (p + 1)..<len {
            if not(is_digit_at(s, i)) {
              all_digits = false
              break
            }
          }
          // Sign must be preceded by a digit that is part of a time component.
          // We require a colon (':') somewhere before the sign to confirm
          // time was present, avoiding false positives on dates like "2024-01-15".
          let preceded_by_digit = p > 0 && is_digit_at(s, p - 1)
          let mut has_colon_before = false
          for i in 0..<p {
            match s.get_char(i) {
              Some(':') => {
                has_colon_before = true
                break
              }
              _ => ()
            }
          }
          if all_digits && preceded_by_digit && has_colon_before {
            let sign = match s.get_char(p) {
              Some('-') => -1
              _ => 1
            }
            let hh = if offset == 3 {
              digit_value_at(s, p + 1) * 10 + digit_value_at(s, p + 2)
            } else {
              digit_value_at(s, p + 1)
            }
            return Some(normalize_tz_offset(sign * hh * 60))
          }
        }
        _ => ()
      }
    }
  }
  None
}

/// Returns the numeric value of the ASCII digit at position `pos`.
///|
fn digit_value_at(s : StringView, pos : Int) -> Int {
  match s.get_char(pos) {
    Some(c) => c.to_int() - '0'.to_int()
    None => 0
  }
}

/// Parses timezone suffix (Z, +HH:MM, -HH:MM, etc.) from position `pos`.
///
/// Returns `(has_tz, tz_offset_min, new_pos)`.
///|
fn parse_tz_suffix(
  s : StringView,
  pos : Int
) -> (Bool, Int, Int) raise ParseError {
  let mut p = pos
  let mut has_tz = false
  let mut tz_offset_min = 0
  if p < s.length() {
    match s.get_char(p) {
      Some('Z') | Some('z') => {
        p += 1
        tz_offset_min = 0
        has_tz = true
      }
      Some('+') | Some('-') => {
        let sign : Int = match s.get_char(p) {
          Some('+') => 1
          _ => -1
        }
        p += 1
        let (tz_h, p8) = parse_int_digits(s, p, 1, 2)
        p = p8
        let mut tz_m = 0
        if p < s.length() {
          match s.get_char(p) {
            Some(':') => {
              p += 1
              let (m, p9) = parse_int_digits(s, p, 1, 2)
              tz_m = m
              p = p9
            }
            Some(c) =>
              if c.is_ascii_digit() {
                let (m, p9) = parse_int_digits(s, p, 2, 2)
                tz_m = m
                p = p9
              }
            None => ()
          }
        }
        tz_offset_min = sign * (tz_h * 60 + tz_m)
        has_tz = true
      }
      _ => ()
    }
  }
  (has_tz, tz_offset_min, p)
}

/// Resolves timezone from parse results.
///
/// Returns `(tz_to_use, parsed_tz_option)` where `parsed_tz_option` is `Some`
/// only when the input contained an explicit timezone.
///|
fn resolve_tz(
  has_tz : Bool,
  tz_offset_min : Int,
  default_tz_offset : TzOffset
) -> (TzOffset, TzOffset?) {
  if has_tz {
    let parsed_tz = normalize_tz_offset(tz_offset_min)
    (parsed_tz, Some(parsed_tz))
  } else {
    (default_tz_offset, None)
  }
}

/// Parses an ISO 8601 datetime string and returns the epoch time in milliseconds.
///
/// Handles date, time, fractional seconds, and timezone offset components.
/// Also supports time-only inputs like `HH:MM[:SS[.mmm]][TZ]` (assumed 1970-01-01).
/// Raises `ParseError` on malformed input.
///|
fn parse_iso8601(
  input : String,
  default_tz_offset~ : TzOffset = Local
) -> Int64 raise ParseError {
  parse_iso8601_with_tz(input, default_tz_offset~).0
}

/// Parses an integer from `min_digits` to `max_digits` decimal digits.
///
/// Returns a tuple of `(value, new_pos)`:
/// - `value` : The parsed integer.
/// - `new_pos` : The position immediately after the consumed digits.
///
/// Raises `ParseError` if fewer than `min_digits` are found.
///|
fn parse_int_digits(
  s : StringView,
  start : Int,
  min_digits : Int,
  max_digits : Int
) -> (Int, Int) raise ParseError {
  let mut pos = start
  let mut value = 0
  let mut count = 0
  while count < max_digits && pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if c.is_ascii_digit() {
          value = value * 10 + (c.to_int() - '0'.to_int())
          pos += 1
          count += 1
        } else {
          break
        }
      None => break
    }
  }
  if count < min_digits {
    raise ParseError(
      "expected at least " +
      min_digits.to_string() +
      " digits at position " +
      start.to_string(),
    )
  }
  (value, pos)
}

/// Returns whether the character at position `pos` is an ASCII digit.
///|
fn is_digit_at(s : StringView, pos : Int) -> Bool {
  match s.get_char(pos) {
    Some(c) => c.is_ascii_digit()
    None => false
  }
}

/// Parses fractional digits up to `max_digits`, discarding any excess digits.
///
/// Returns a tuple of `(value, digits_read, new_pos)`:
/// - `value` : The numeric value of the digits read (not yet scaled).
/// - `digits_read` : The number of significant digits consumed (up to `max_digits`).
/// - `new_pos` : The position after all digits (including discarded excess).
///|
fn parse_frac_digits(
  s : StringView,
  start : Int,
  max_digits : Int
) -> (Int, Int, Int) {
  let mut pos = start
  let mut value = 0
  let mut count = 0
  while count < max_digits && pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if c.is_ascii_digit() {
          value = value * 10 + (c.to_int() - '0'.to_int())
          pos += 1
          count += 1
        } else {
          break
        }
      None => break
    }
  }
  // max_digits を超える余分な桁は読み飛ばす
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
  (value, count, pos)
}

/// Skips an optional date separator (`-` or `/`) at position `pos`.
///|
fn skip_date_sep(s : StringView, pos : Int) -> Int {
  match s.get_char(pos) {
    Some('-') | Some('/') => pos + 1
    _ => pos
  }
}

/// Skips an optional time separator (`:`) at position `pos`.
///|
fn skip_time_sep(s : StringView, pos : Int) -> Int {
  match s.get_char(pos) {
    Some(':') => pos + 1
    _ => pos
  }
}

/// Converts date-time components to epoch milliseconds with normalization.
///
/// Uses Go-style mktime normalization: out-of-range values for seconds, minutes,
/// hours, days, and months are carried over to the next higher unit.
/// The timezone offset is subtracted to produce a UTC epoch value.
///|
fn datetime_to_epoch(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  min : Int,
  sec : Int,
  ms : Int,
  tz_offset~ : TzOffset = Utc
) -> Int64 {
  // TzOffset → 分単位オフセットに変換して UTC 化
  let offset_min = tz_offset_to_minutes(tz_offset)
  let mut y = year
  let mut mo = month
  let mut d = day
  let mut h = hour
  let mut mi = min - offset_min
  let mut s = sec
  // 1. 秒→分→時→日の繰り上げ/繰り下げ
  mi += floor_div(s, 60)
  s = floor_mod(s, 60)
  h += floor_div(mi, 60)
  mi = floor_mod(mi, 60)
  d += floor_div(h, 24)
  h = floor_mod(h, 24)
  // 2. 月の正規化: 1-12 の範囲に
  y += floor_div(mo - 1, 12)
  mo = floor_mod(mo - 1, 12) + 1
  // 3. 日の正規化: 月の日数に基づき繰り上げ/繰り下げ
  while d > days_in_month(y, mo) {
    d -= days_in_month(y, mo)
    mo += 1
    if mo > 12 {
      mo = 1
      y += 1
    }
  }
  while d <= 0 {
    mo -= 1
    if mo <= 0 {
      mo = 12
      y -= 1
    }
    d += days_in_month(y, mo)
  }
  // epoch 変換: 通算日数の計算（1970-01-01 = 0）
  let days = days_from_epoch(y, mo, d)
  (days.to_int64() * 86400L + h.to_int64() * 3600L + mi.to_int64() * 60L +
  s.to_int64()) *
  1000L +
  ms.to_int64()
}

/// Computes the number of days from 1970-01-01 for a given civil date.
/// Uses Howard Hinnant's algorithm.
///|
fn days_from_epoch(year : Int, month : Int, day : Int) -> Int {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let m = month
  let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

/// Converts days since 1970-01-01 back to a civil date `(year, month, day)`.
/// Uses Howard Hinnant's algorithm.
///|
fn epoch_days_to_civil(total_days : Int) -> (Int, Int, Int) {
  let z = total_days + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = if m <= 2 { y + 1 } else { y }
  (year, m, d)
}

/// Returns the number of days in the given month, accounting for leap years.
///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 => 31
    2 => if is_leap_year(year) { 29 } else { 28 }
    3 => 31
    4 => 30
    5 => 31
    6 => 30
    7 => 31
    8 => 31
    9 => 30
    10 => 31
    11 => 30
    12 => 31
    _ => 30
  }
}

/// Returns whether the given year is a leap year.
///|
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

/// Converts epoch milliseconds to an ISO 8601 datetime string.
///
/// Parameters:
///
/// * `epoch_ms` : Milliseconds since 1970-01-01T00:00:00Z.
/// * `tz_offset` : The timezone offset to apply. Defaults to `Utc`.
///   With `Utc`, the output ends in `Z`. With `Hour(9)`, it ends in `+09:00`.
///   With `Local`, the system timezone is queried at runtime.
///
/// Returns a formatted string like `"2025-03-15T00:56:14Z"` or
/// `"2025-03-15T09:56:14+09:00"`. Milliseconds are included only when non-zero
/// (e.g. `"2025-03-15T00:56:14.123Z"`).
///|
pub fn epoch_to_iso8601(
  epoch_ms : Int64,
  tz_offset~ : TzOffset = Utc
) -> String {
  // Local を解決してから TZ サフィックス用に保持
  let resolved_tz = match tz_offset {
    Local => local_tz_offset()
    _ => tz_offset
  }
  // TzOffset に応じて epoch_ms にオフセットを加算
  let offset_min = tz_offset_to_minutes(resolved_tz)
  let adjusted = epoch_ms + offset_min.to_int64() * 60L * 1000L
  // epoch_ms → 年月日時分秒に逆変換
  let total_ms = adjusted
  let mut total_seconds = total_ms / 1000L
  let mut ms = (total_ms % 1000L).to_int()
  // 負値対応
  if ms < 0 {
    ms += 1000
    total_seconds -= 1L
  }
  let mut total_days = (total_seconds / 86400L).to_int()
  let mut remaining = (total_seconds % 86400L).to_int()
  if remaining < 0 {
    remaining += 86400
    total_days -= 1
  }
  let hour = remaining / 3600
  let min = (remaining % 3600) / 60
  let sec = remaining % 60
  // total_days から年月日を逆算（Howard Hinnant's algorithm）
  let (year, month, day) = epoch_days_to_civil(total_days)
  // 文字列構築
  let buf = StringBuilder::new()
  buf.write_string(pad4(year))
  buf.write_char('-')
  buf.write_string(pad2(month))
  buf.write_char('-')
  buf.write_string(pad2(day))
  buf.write_char('T')
  buf.write_string(pad2(hour))
  buf.write_char(':')
  buf.write_string(pad2(min))
  buf.write_char(':')
  buf.write_string(pad2(sec))
  // ミリ秒が非ゼロなら .NNN 付与
  if ms != 0 {
    buf.write_char('.')
    buf.write_string(pad3(ms))
  }
  // TzOffset サフィックス
  match resolved_tz {
    Utc => buf.write_char('Z')
    Hour(h) => {
      if h >= 0 {
        buf.write_char('+')
        buf.write_string(pad2(h))
        buf.write_string(":00")
      } else {
        buf.write_char('-')
        buf.write_string(pad2(-h))
        buf.write_string(":00")
      }
    }
    Min(m) => {
      let abs_m = if m >= 0 { m } else { -m }
      if m >= 0 {
        buf.write_char('+')
      } else {
        buf.write_char('-')
      }
      buf.write_string(pad2(abs_m / 60))
      buf.write_char(':')
      buf.write_string(pad2(abs_m % 60))
    }
    Local => () // unreachable
  }
  buf.to_string()
}

/// Zero-pads an integer to 2 digits.
///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

/// Zero-pads an integer to 3 digits.
///|
fn pad3(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

/// Zero-pads an integer to 4 digits. Handles negative values for BCE years.
///|
fn pad4(n : Int) -> String {
  if n < 0 {
    "-" + pad4(-n)
  } else if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

/// Floor division that rounds toward negative infinity (Python-style).
///|
fn floor_div(a : Int, b : Int) -> Int {
  if (a >= 0) == (b > 0) {
    a / b
  } else {
    (a - b + 1) / b
  }
}

/// Floor modulo that always returns a non-negative result (Python-style).
///|
fn floor_mod(a : Int, b : Int) -> Int {
  a - floor_div(a, b) * b
}
