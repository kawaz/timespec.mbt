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
  let minutes = local_tz_offset_minutes_ffi()
  if minutes == 0 {
    Utc
  } else if minutes % 60 == 0 {
    Hour(minutes / 60)
  } else {
    Min(minutes)
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
  // 先頭の符号を取得
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
  // duration 形式の判定: pos 以降に h, m, s が含まれるか
  let is_duration = contains_duration_unit(s, pos)
  let total_minutes : Int = if is_duration {
    // parse_duration に元のトリム済み文字列を渡す
    let trimmed = input.trim().to_string()
    let dur = parse_duration(trimmed, default_sign=Plus)
    let ms = dur.0
    // TZ オフセットは分単位。分に割り切れない場合はエラー
    if ms % 60_000L != 0L {
      raise ParseError("timezone offset must be in whole minutes, got: " + trimmed)
    }
    (ms / 60_000L).to_int()
  } else {
    // 数値形式のパース
    parse_numeric_offset(s, pos, sign)
  }
  // 範囲チェック: TZ オフセットは ±24 時間 (±1440 分) 以内
  if total_minutes > 1440 || total_minutes < -1440 {
    raise ParseError(
      "timezone offset out of range (must be within ±24 hours): " + input,
    )
  }
  // ゼロオフセットの正規化
  if total_minutes == 0 {
    Utc
  } else if total_minutes % 60 == 0 {
    Hour(total_minutes / 60)
  } else {
    Min(total_minutes)
  }
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
  // 最初の数値部分を読む（TZ オフセットは最大 HHMM の4桁）
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
  // コロンがあるか確認
  match s.get_char(pos) {
    Some(':') => {
      // HH:MM 形式
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
        // 1-2桁: 時のみ
        if pos < s.length() {
          raise ParseError("unexpected trailing characters in timezone offset: " + s.to_string())
        }
        sign * first_num * 60
      } else if first_digits == 4 {
        // 4桁: HHMM
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
