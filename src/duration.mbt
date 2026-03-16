/// One millisecond.
///|
pub let millisecond : Duration = Duration(1L)

/// One second (1,000 ms).
///|
pub let second : Duration = Duration(1_000L)

/// One minute (60,000 ms).
///|
pub let minute : Duration = Duration(60_000L)

/// One hour (3,600,000 ms).
///|
pub let hour : Duration = Duration(3_600_000L)

/// One day (86,400,000 ms).
///|
pub let day : Duration = Duration(86_400_000L)

/// One week (604,800,000 ms).
///|
pub let week : Duration = Duration(604_800_000L)

/// Adds two durations.
///|
pub impl Add for Duration with add(a, b) {
  Duration(a.0 + b.0)
}

/// Subtracts one duration from another.
///|
pub impl Sub for Duration with sub(a, b) {
  Duration(a.0 - b.0)
}

/// Negates a duration, reversing its direction.
///|
pub impl Neg for Duration with neg(self) {
  Duration(-self.0)
}

/// Multiplies a duration by a scalar value.
///
/// Parameters:
///
/// * `self` : The duration to scale.
/// * `n` : The multiplier.
///
/// Returns a new `Duration` whose millisecond value is `self * n`.
///|
pub fn Duration::scale(self : Duration, n : Int64) -> Duration {
  Duration(self.0 * n)
}

/// Adds a duration to an epoch time, producing a new epoch time.
///
/// Parameters:
///
/// * `self` : The base epoch time.
/// * `d` : The duration to add (may be negative to subtract).
///
/// Returns a new `EpochTime` offset by `d` milliseconds.
///|
pub fn EpochTime::add_duration(self : EpochTime, d : Duration) -> EpochTime {
  EpochTime(self.0 + d.0)
}

/// Adds two `Int64` values with overflow detection.
/// Raises `ParseError` with the given message if overflow occurs.
///|
fn checked_add(a : Int64, b : Int64, msg~ : String = "overflow") -> Int64 raise ParseError {
  let result = a + b
  // オーバーフロー検出: 符号が反転した場合
  if (a > 0L && b > 0L && result < 0L) ||
    (a < 0L && b < 0L && result > 0L) {
    raise ParseError(msg)
  }
  result
}

/// Multiplies two `Int64` values with overflow detection.
/// Raises `ParseError` with the given message if overflow occurs.
///|
fn checked_mul(a : Int64, b : Int64, msg~ : String = "overflow") -> Int64 raise ParseError {
  if a == 0L || b == 0L {
    return 0L
  }
  let result = a * b
  if result / a != b {
    raise ParseError(msg)
  }
  result
}

/// Parses a duration string into a `Duration`.
///
/// Supports integers, decimals, underscore separators, and compound expressions.
/// Units: `w`/`week(s)`, `d`/`day(s)`, `h`/`hour(s)`, `m`/`min`/`minute(s)`,
/// `s`/`sec`/`second(s)`, `ms`/`millisecond(s)`.
/// The `ago` modifier reverses the sign of the preceding segment group.
///
/// Parameters:
///
/// * `input` : The duration string to parse (e.g. `"5m"`, `"1h30m"`, `"3_600_000ms"`,
///   `"1.5h"`, `"5 minutes ago"`).
/// * `default_sign~` : How to interpret input without an explicit `+`/`-` sign.
///   Defaults to `Plus`.
///
/// Returns a `Duration` in milliseconds.
///
/// Raises `ParseError` if the input is empty, contains unknown units, or overflows.
///|
pub fn parse_duration(
  input : String,
  default_sign~ : Sign = Plus
) -> Duration raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty duration string")
  }
  let mut pos = 0
  // 先頭の符号を判定
  let negate : Bool = match s.get_char(pos) {
    Some('+') => {
      pos += 1
      false
    }
    Some('-') => {
      pos += 1
      true
    }
    _ =>
      match default_sign {
        Minus => true
        Plus => false
        Reject => raise ParseError("missing sign in duration: " + input)
      }
  }
  // スペースをスキップ
  pos = skip_spaces(s, pos)
  // グループベースのパース
  // グループ = 明示的 +/- で区切られた連続セグメント
  // ago はグループ全体を反転し、次のグループを開始する
  let mut total_ms = 0L
  let mut group_ms = 0L
  let mut group_sign = 1L
  let mut parsed_any = false
  while pos < s.length() {
    // スペースをスキップ
    pos = skip_spaces(s, pos)
    if pos >= s.length() {
      break
    }
    // 明示 +/- でグループを区切る
    let saved_pos = pos
    let mut new_group = false
    match s.get_char(pos) {
      Some('+') => {
        total_ms = checked_add(
          total_ms,
          checked_mul(group_sign, group_ms, msg="duration overflow"),
          msg="duration overflow",
        )
        group_ms = 0L
        group_sign = 1L
        pos += 1
        new_group = true
      }
      Some('-') => {
        total_ms = checked_add(
          total_ms,
          checked_mul(group_sign, group_ms, msg="duration overflow"),
          msg="duration overflow",
        )
        group_ms = 0L
        group_sign = -1L
        pos += 1
        new_group = true
      }
      _ => ()
    }
    pos = skip_spaces(s, pos)
    if pos >= s.length() {
      if new_group {
        pos = saved_pos
      }
      break
    }
    // 数値でなければ ago チェック
    match s.get_char(pos) {
      Some(ch) =>
        if not(ch.is_ascii_digit()) {
          // ago チェック
          if try_match_word(s, pos, "ago") {
            group_ms = -group_ms
            total_ms = checked_add(
              total_ms,
              checked_mul(group_sign, group_ms, msg="duration overflow"),
              msg="duration overflow",
            )
            group_ms = 0L
            group_sign = 1L
            pos += 3
            continue
          }
          if new_group {
            pos = saved_pos // 符号消費を元に戻す
          }
          break
        }
      None => {
        if new_group {
          pos = saved_pos
        }
        break
      }
    }
    let (integer_part, fractional_part, new_pos) = parse_number(s, pos)
    pos = new_pos
    pos = skip_spaces(s, pos)
    // ユニットを読む
    let (ms_mul, unit_end) = parse_unit(s, pos)
    if unit_end == pos {
      raise ParseError("missing unit after number in: " + input)
    }
    pos = unit_end
    // 整数部の計算
    let mut seg_ms = checked_mul(integer_part, ms_mul, msg="duration overflow")
    // 小数部（ms に変換）
    if fractional_part > 0.0 {
      let frac_ms = (fractional_part * ms_mul.to_double()).to_int64()
      seg_ms = checked_add(seg_ms, frac_ms, msg="duration overflow")
    }
    // グループに累積
    group_ms = checked_add(group_ms, seg_ms, msg="duration overflow")
    parsed_any = true
    // ユニット直後の ago チェック
    pos = skip_spaces(s, pos)
    if try_match_word(s, pos, "ago") {
      group_ms = -group_ms
      total_ms = checked_add(
        total_ms,
        checked_mul(group_sign, group_ms, msg="duration overflow"),
        msg="duration overflow",
      )
      group_ms = 0L
      group_sign = 1L
      pos += 3
    }
  }
  if not(parsed_any) {
    raise ParseError("no duration segments found in: " + input)
  }
  // 残りのグループをフラッシュ
  total_ms = checked_add(
    total_ms,
    checked_mul(group_sign, group_ms, msg="duration overflow"),
    msg="duration overflow",
  )
  // 末尾に余分な文字があればエラー
  pos = skip_spaces(s, pos)
  if pos < s.length() {
    raise ParseError("unexpected characters after duration: " + input)
  }
  // 全体符号の適用（先頭の +/- or default_sign）
  if negate {
    total_ms = -total_ms
  }
  Duration(total_ms)
}

/// Skips whitespace characters (space, tab) starting from `start`.
/// Returns the position of the first non-whitespace character.
///|
fn skip_spaces(s : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < s.length() {
    match s.get_char(pos) {
      Some(' ') | Some('\t') => pos += 1
      _ => break
    }
  }
  pos
}

/// Parses a numeric value with optional fractional part and underscore separators.
///
/// Returns a tuple of `(integer_part, fractional_part, new_pos)`:
/// - `integer_part` : The whole number portion as `Int64`.
/// - `fractional_part` : The decimal portion as `Double` (0.0 if absent).
/// - `new_pos` : The position immediately after the parsed number.
///|
fn parse_number(s : StringView, start : Int) -> (Int64, Double, Int) raise ParseError {
  let mut pos = start
  let mut integer_part = 0L
  // 整数部
  let max_div = 922_337_203_685_477_580L // Int64::max_value / 10
  let max_mod = 7 // Int64::max_value % 10
  while pos < s.length() {
    match s.get_char(pos) {
      Some('_') => pos += 1
      Some(c) =>
        if c.is_ascii_digit() {
          let digit = c.to_int() - '0'.to_int()
          if integer_part > max_div ||
            (integer_part == max_div && digit > max_mod) {
            raise ParseError("number too large")
          }
          integer_part = integer_part * 10L + digit.to_int64()
          pos += 1
        } else {
          break
        }
      None => break
    }
  }
  // 小数部
  let mut frac_part = 0.0
  match s.get_char(pos) {
    Some('.') => {
      pos += 1
      let mut frac_digits = 0
      while pos < s.length() {
        match s.get_char(pos) {
          Some('_') => pos += 1
          Some(c) =>
            if c.is_ascii_digit() {
              frac_digits += 1
              frac_part = frac_part * 10.0 + (c.to_int() - '0'.to_int()).to_double()
              pos += 1
            } else {
              break
            }
          None => break
        }
      }
      // scale fractional part
      let mut scale = 1.0
      for _i in 0..<frac_digits {
        scale *= 10.0
      }
      frac_part = frac_part / scale
    }
    _ => ()
  }
  (integer_part, frac_part, pos)
}

/// Checks if `s[pos..]` starts with `word` and is followed by a non-alphabetic
/// character or EOF (to prevent partial matches like "min" matching "minutes").
///|
fn try_match_word(s : StringView, pos : Int, word : String) -> Bool {
  let wlen = word.length()
  if pos + wlen > s.length() {
    return false
  }
  for i in 0..<wlen {
    match (s.get_char(pos + i), word.get_char(i)) {
      (Some(a), Some(b)) => if a != b { return false }
      _ => return false
    }
  }
  // word の後は非アルファベット文字か EOF であること（部分一致防止）
  match s.get_char(pos + wlen) {
    Some(c) => not(c.is_ascii_lowercase() || c.is_ascii_uppercase())
    None => true
  }
}

/// Reads a duration unit starting at `pos` and returns its millisecond multiplier.
///
/// Returns a tuple of `(ms_multiplier, end_pos)`:
/// - `ms_multiplier` : The number of milliseconds per one unit (e.g. 3,600,000 for `h`).
/// - `end_pos` : The position immediately after the consumed unit string.
///
/// Raises `ParseError` for unknown or sub-millisecond units (`us`, `ns`).
///|
fn parse_unit(
  s : StringView,
  pos : Int
) -> (Int64, Int) raise ParseError {
  match s.get_char(pos) {
    Some('w') =>
      match s.get_char(pos + 1) {
        Some('e') =>
          if try_match_word(s, pos, "weeks") {
            (604_800_000L, pos + 5)
          } else if try_match_word(s, pos, "week") {
            (604_800_000L, pos + 4)
          } else {
            raise ParseError(
              "unknown unit at position " + pos.to_string() + " in: " +
              s.to_string(),
            )
          }
        _ => (604_800_000L, pos + 1) // 'w'
      }
    Some('d') =>
      match s.get_char(pos + 1) {
        Some('a') =>
          if try_match_word(s, pos, "days") {
            (86_400_000L, pos + 4)
          } else if try_match_word(s, pos, "day") {
            (86_400_000L, pos + 3)
          } else {
            raise ParseError(
              "unknown unit at position " + pos.to_string() + " in: " +
              s.to_string(),
            )
          }
        _ => (86_400_000L, pos + 1) // 'd'
      }
    Some('h') =>
      match s.get_char(pos + 1) {
        Some('o') =>
          if try_match_word(s, pos, "hours") {
            (3_600_000L, pos + 5)
          } else if try_match_word(s, pos, "hour") {
            (3_600_000L, pos + 4)
          } else {
            raise ParseError(
              "unknown unit at position " + pos.to_string() + " in: " +
              s.to_string(),
            )
          }
        _ => (3_600_000L, pos + 1) // 'h'
      }
    Some('m') =>
      match s.get_char(pos + 1) {
        Some('s') => (1L, pos + 2) // 'ms'
        Some('i') =>
          if try_match_word(s, pos, "minutes") {
            (60_000L, pos + 7)
          } else if try_match_word(s, pos, "minute") {
            (60_000L, pos + 6)
          } else if try_match_word(s, pos, "min") {
            (60_000L, pos + 3)
          } else if try_match_word(s, pos, "milliseconds") {
            (1L, pos + 12)
          } else if try_match_word(s, pos, "millisecond") {
            (1L, pos + 11)
          } else {
            raise ParseError(
              "unknown unit at position " + pos.to_string() + " in: " +
              s.to_string(),
            )
          }
        _ => (60_000L, pos + 1) // 'm'
      }
    Some('s') =>
      match s.get_char(pos + 1) {
        Some('e') =>
          if try_match_word(s, pos, "seconds") {
            (1_000L, pos + 7)
          } else if try_match_word(s, pos, "second") {
            (1_000L, pos + 6)
          } else if try_match_word(s, pos, "sec") {
            (1_000L, pos + 3)
          } else {
            raise ParseError(
              "unknown unit at position " + pos.to_string() + " in: " +
              s.to_string(),
            )
          }
        _ => (1_000L, pos + 1) // 's'
      }
    Some('u') =>
      match s.get_char(pos + 1) {
        Some('s') =>
          raise ParseError(
            "sub-millisecond unit 'us' is not supported",
          )
        _ =>
          raise ParseError(
            "unknown unit 'u' at position " +
            pos.to_string() +
            " (did you mean 'us'? Note: sub-ms units are not supported)",
          )
      }
    Some('\u03BC') =>
      // μ (U+03BC)
      match s.get_char(pos + 1) {
        Some('s') =>
          raise ParseError(
            "sub-millisecond unit '\u03BCs' is not supported",
          )
        _ =>
          raise ParseError(
            "unknown unit '\u03BC' at position " +
            pos.to_string() +
            " (did you mean '\u03BCs'? Note: sub-ms units are not supported)",
          )
      }
    Some('n') =>
      match s.get_char(pos + 1) {
        Some('s') =>
          raise ParseError(
            "sub-millisecond unit 'ns' is not supported",
          )
        _ =>
          raise ParseError(
            "unknown unit 'n' at position " +
            pos.to_string() +
            " (did you mean 'ns'? Note: sub-ms units are not supported)",
          )
      }
    Some(c) =>
      raise ParseError(
        "unknown unit '" + c.to_string() + "' at position " + pos.to_string(),
      )
    None => (0L, pos) // no unit found
  }
}
