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
/// * `epoch~` : Base epoch offset subtracted from absolute results. Defaults to Unix epoch.
/// * `default_sign~` : How to interpret unsigned durations. Defaults to `Plus`.
/// * `default_tz_offset~` : Default timezone for TZ-less datetimes. Defaults to `Utc`.
/// * `now~` : Clock function returning the current time in ms. Defaults to `@env.now`.
/// * `parse_datetime~` : Pluggable datetime parser. Defaults to `default_parse_datetime`.
///
/// Returns a `TimeSpec` -- either `Absolute` or `Relative`.
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
) -> TimeSpec raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty timespec string")
  }
  // ===== Phase 1: Leading sign + Duration segment extraction =====
  let mut pos = 0
  // 先頭の @ をチェック
  let mut has_at = false
  match s.get_char(pos) {
    Some('@') => {
      has_at = true
      pos += 1
    }
    _ => ()
  }
  // 先頭の符号をチェック
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
          false // 仮の値
        }
      }
  }
  pos = skip_spaces(s, pos)
  // 文字列を走査: duration セグメントの ms を直接累積、非 duration 部分は蓄積
  let non_duration_buf = StringBuilder::new()
  let mut has_duration = false
  let mut total_duration_ms = 0L
  // 先頭符号の適用: 最初の無符号 duration セグメントグループに negate を適用
  // セグメントグループ = 明示符号で区切られた連続 duration セグメント列
  // 最初のグループの符号は negate (先頭符号) に従い、以降は明示符号に従う
  let mut current_group_ms = 0L
  let mut current_group_sign : Int64 = if negate { -1L } else { 1L }
  let mut in_first_group = true // まだ最初のグループにいるか
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
    // 符号を先読み
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
    // 数字で始まるか確認
    if is_digit_at(s, after_sign) {
      // duration セグメント候補を試みる
      let probe_result = probe_duration_segment(s, after_sign)
      match probe_result {
        Some((seg_ms, is_ago, dur_end)) => {
          // duration セグメント確定
          has_duration = true
          // ago による反転を適用
          let effective_ms = if is_ago { -seg_ms } else { seg_ms }
          match seg_sign_char {
            Some('+') => {
              // 明示 +: 現在グループをフラッシュして新グループ開始
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
              // 明示 -: 現在グループをフラッシュして新グループ開始
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
              // 符号なし: 現在グループに累積
              current_group_ms = checked_add(
                current_group_ms, effective_ms, msg="timespec overflow",
              )
            }
          }
          scan_pos = dur_end
          continue
        }
        None => {
          // duration ではない → 非 duration
          scan_pos = seg_sign_start
          let non_dur_end = scan_non_duration(s, scan_pos)
          non_duration_buf.write_string(s[scan_pos:non_dur_end].to_string())
          scan_pos = non_dur_end
          continue
        }
      }
    } else {
      // 数字で始まらない → 非 duration
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
  // 最後のグループをフラッシュ
  if has_duration {
    total_duration_ms = checked_add(
      total_duration_ms,
      checked_mul(current_group_sign, current_group_ms, msg="timespec overflow"),
      msg="timespec overflow",
    )
  }
  let duration = Duration(total_duration_ms)
  // ===== Phase 2: @ マーカー検出 (走査中に has_at を設定済み) =====
  // ===== Phase 3: Time-of-day パターンの検出 =====
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
  // ===== Phase 3.5: Raw epoch ms の検出 =====
  // @付きで残り文字列が [+-]?数字のみ → raw epoch ms（date -d @EPOCH 規約）
  // 先頭符号が Phase 1 で消費されているので復元する
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
  // ===== Phase 4: datetime パース =====
  let mut has_datetime = false
  let mut dt_epoch_ms = 0L
  let mut tz_offset_datetime : TzOffset? = None
  if datetime_str.length() > 0 {
    match parse_datetime(datetime_str) {
      Some(epoch_ms) => {
        has_datetime = true
        dt_epoch_ms = epoch_ms
        // TzOffset 情報を文字列末尾から独立検出（パーサ非依存）
        tz_offset_datetime = detect_tz_suffix(datetime_str)
      }
      None =>
        raise ParseError(
          "failed to parse datetime: " + datetime_str + " in: " + input,
        )
    }
  }
  // ===== Phase 5: EpochTime の構築 =====
  if not(has_duration) && not(has_datetime) && not(has_raw_epoch) && time_of_day_ms is None && not(has_at) {
    raise ParseError("no duration or datetime found in: " + input)
  }
  // Reject モードチェック: duration のみで datetime/time-of-day/raw epoch がない場合
  if needs_sign && not(has_datetime) && not(has_raw_epoch) && time_of_day_ms is None {
    raise ParseError("missing sign in timespec: " + input)
  }
  // 基準 epoch_ms の決定
  let mut base_epoch_ms = 0L
  if has_raw_epoch {
    base_epoch_ms = raw_epoch_ms
  } else if has_datetime {
    base_epoch_ms = dt_epoch_ms
  } else {
    base_epoch_ms = now().reinterpret_as_int64()
  }
  // Time-of-day リセット
  match time_of_day_ms {
    Some(tod_ms) => {
      // TzOffset 整合性チェック
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
      // 基準をローカル midnight に切り落とし
      let offset_minutes = tz_offset_to_minutes(effective_tod_tz)
      let offset_ms = offset_minutes.to_int64() * 60_000L
      let local_ms = base_epoch_ms + offset_ms
      let local_midnight = local_ms - floor_mod_i64(local_ms, 86_400_000L)
      let utc_midnight = local_midnight - offset_ms
      base_epoch_ms = utc_midnight + tod_ms
    }
    None => ()
  }
  // Duration を加算
  let final_epoch_ms = checked_add(
    base_epoch_ms - epoch.0, duration.0, msg="timespec overflow",
  )
  // ===== Phase 6: TimeSpec の構築 =====
  let epoch_time = EpochTime(final_epoch_ms)
  if has_at || has_datetime {
    Absolute(epoch_time, duration)
  } else {
    Relative(epoch_time, duration)
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
  // 数字部分を読む
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
  // ユニット文字があるか確認
  let unit_result = try {
    parse_unit(s, after_num)
  } catch {
    _ => (0L, after_num)
  }
  let (ms_mul, unit_end) = unit_result
  if unit_end == after_num {
    return None // ユニットがない → duration ではない
  }
  // 数値を実際にパース
  let (integer_part, fractional_part, _) = parse_number(s, pos)
  // ms の計算
  let mut seg_ms = checked_mul(integer_part, ms_mul, msg="timespec overflow")
  if fractional_part > 0.0 {
    let frac_ms = (fractional_part * ms_mul.to_double()).to_int64()
    seg_ms = checked_add(seg_ms, frac_ms, msg="timespec overflow")
  }
  // ago チェック
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
  // 4桁年パターンを検索
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
    // datetime 部分の終端を探す
    let dt_end = find_datetime_end_sv(sv, dt_start)
    let dt_part = sv[dt_start:dt_end].to_string().trim().to_string()
    // datetime 以外の部分に time-of-day があるか
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
          // space: datetime の T セパレータの可能性。次が数字でなければ終了
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
  // 先頭の符号をスキップ
  match sv.get_char(0) {
    Some('+') | Some('-') => i = 1
    _ => ()
  }
  if i >= sv.length() {
    return false // 符号のみ
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
