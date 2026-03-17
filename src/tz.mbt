/// Returns the system's local timezone offset.
///
/// The implementation is target-dependent:
/// - **Native**: calls a C FFI stub (`local_tz_offset_minutes`).
/// - **JS**: uses `new Date().getTimezoneOffset()` (sign-inverted).
/// - **WASM**: returns `Utc` (WASI has no timezone API).
///
/// The result is normalized to `Utc`, `Hour(n)`, or `Min(n)`.
///|
pub fn local_tz_offset() -> TzOffset {
  normalize_tz_offset(local_tz_offset_minutes_ffi())
}

/// Normalizes a minute-based offset into the canonical `TzOffset` representation.
///
/// - `0` → `Utc`
/// - Divisible by 60 → `Hour(n)`
/// - Otherwise → `Min(n)`
///|
fn normalize_tz_offset(minutes : Int) -> TzOffset {
  if minutes == 0 {
    Utc
  } else if minutes % 60 == 0 {
    Hour(minutes / 60)
  } else {
    Min(minutes)
  }
}

/// Converts a `TzOffset` to its equivalent in minutes.
///
/// `Local` is resolved to the system timezone before conversion.
///|
fn tz_offset_to_minutes(tz : TzOffset) -> Int {
  match tz {
    Utc => 0
    Hour(h) => h * 60
    Min(m) => m
    Local => tz_offset_to_minutes(local_tz_offset())
  }
}

/// Parses a timezone offset string into a `TzOffset`.
///
/// Accepted input patterns:
/// - Empty string, `"Z"`, `"z"`, `"UTC"` (case-insensitive) → `Utc`
/// - `"local"` (case-insensitive) → `Local`
/// - Numeric: `"9"`, `"+09"`, `"+0900"`, `"+09:00"` → `Hour(9)`
/// - Duration: `"5h30m"`, `"+5h30m"` → `Min(330)`
/// - Negative: `"-5h"` → `Hour(-5)`
///
/// Parameters:
///
/// * `input` : The timezone offset string.
///
/// Returns a normalized `TzOffset` (`Utc`, `Hour`, or `Min`).
///
/// Raises `ParseError` for sub-minute precision or invalid formats.
///|
pub fn parse_tz_offset(input : String) -> TzOffset raise ParseError {
  let s = input.trim()
  let len = s.length()
  if len == 0 {
    return Utc
  }
  let lower = s.to_lower()
  // Z → Utc
  if lower == "z" {
    return Utc
  }
  // UTC/GMT prefix → strip and re-parse remainder
  // Handles: "UTC", "GMT", "UTC+0900", "GMT+9", "GMT +09:00" etc.
  if len >= 3 && (lower[:3] == "utc" || lower[:3] == "gmt") {
    let rest = s[3:].to_string().trim()
    if rest.length() == 0 {
      return Utc
    }
    return parse_tz_offset(rest.to_string())
  }
  // local → Local
  if lower == "local" {
    return Local
  }
  // Get the leading sign
  let mut pos = 0
  let sign : Int = match s.get_char(pos) {
    Some('+') => {
      pos += 1
      1
    }
    Some('-') => {
      pos += 1
      -1
    }
    _ => 1
  }
  // Detect duration format: check if h, m, or s appears from pos onward
  let is_duration = contains_duration_unit(s, pos)
  let total_minutes : Int = if is_duration {
    // Pass the original trimmed string to parse_duration
    let trimmed = input.trim().to_string()
    let dur = parse_duration(trimmed, default_sign=Plus)
    let ms = dur.0
    // TZ offset is in minutes. Error if not evenly divisible
    if ms % 60_000L != 0L {
      raise ParseError("timezone offset must be in whole minutes, got: " + trimmed)
    }
    (ms / 60_000L).to_int()
  } else {
    // Parse numeric format
    parse_numeric_offset(s, pos, sign)
  }
  // Range check: TZ offset must be within +/-24 hours (+/-1440 minutes)
  if total_minutes > 1440 || total_minutes < -1440 {
    raise ParseError(
      "timezone offset out of range (must be within ±24 hours): " + input,
    )
  }
  normalize_tz_offset(total_minutes)
}

/// Checks if the string contains a duration unit character (`h`, `m`, `s`)
/// at or after position `start`, to distinguish duration format from numeric format.
///|
fn contains_duration_unit(s : StringView, start : Int) -> Bool {
  let mut i = start
  while i < s.length() {
    match s.get_char(i) {
      Some('h') | Some('m') | Some('s') => return true
      _ => i += 1
    }
  }
  false
}

/// Parses a numeric timezone offset in `HH`, `HHMM`, or `HH:MM` format.
/// Returns the total offset in minutes, with the sign applied.
///|
fn parse_numeric_offset(
  s : StringView,
  start : Int,
  sign : Int
) -> Int raise ParseError {
  let mut pos = start
  // Read the first numeric part (TZ offset is at most 4 digits for HHMM)
  let mut first_num = 0
  let mut first_digits = 0
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if c.is_ascii_digit() {
          first_digits += 1
          if first_digits > 4 {
            raise ParseError("too many digits in timezone offset")
          }
          first_num = first_num * 10 + (c.to_int() - '0'.to_int())
          pos += 1
        } else {
          break
        }
      None => break
    }
  }
  if first_digits == 0 {
    raise ParseError("expected digit in timezone offset")
  }
  // Check for colon separator
  match s.get_char(pos) {
    Some(':') => {
      // HH:MM format
      pos += 1
      let mut mm = 0
      let mut mm_digits = 0
      while pos < s.length() {
        match s.get_char(pos) {
          Some(c) =>
            if c.is_ascii_digit() {
              mm = mm * 10 + (c.to_int() - '0'.to_int())
              mm_digits += 1
              pos += 1
            } else {
              break
            }
          None => break
        }
      }
      if mm_digits == 0 {
        raise ParseError("expected minutes after ':' in timezone offset")
      }
      if pos < s.length() {
        raise ParseError("unexpected trailing characters in timezone offset: " + s.to_string())
      }
      sign * (first_num * 60 + mm)
    }
    _ =>
      if first_digits <= 2 {
        // 1-2 digits: hours only
        if pos < s.length() {
          raise ParseError("unexpected trailing characters in timezone offset: " + s.to_string())
        }
        sign * first_num * 60
      } else if first_digits == 4 {
        // 4 digits: HHMM
        if pos < s.length() {
          raise ParseError("unexpected trailing characters in timezone offset: " + s.to_string())
        }
        let hh = first_num / 100
        let mm = first_num % 100
        sign * (hh * 60 + mm)
      } else {
        raise ParseError("invalid timezone offset format")
      }
  }
}
