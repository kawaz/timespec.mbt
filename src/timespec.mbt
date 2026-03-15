///| parse_timespec: 1つの timespec パートをパースする
pub fn parse_timespec(
  input : String,
  default_sign~ : Sign = Plus,
  now~ : () -> UInt64 = @env.now,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeSpec raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty timespec string")
  }
  let mut pos = 0
  // 1. 先頭の @ をチェック
  let mut has_at = false
  match s.get_char(pos) {
    Some('@') => {
      has_at = true
      pos += 1
    }
    _ => ()
  }
  // 2. 先頭の符号をチェック
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
        Reject => raise ParseError("missing sign in timespec: " + input)
      }
  }
  pos = skip_spaces(s, pos)
  // 3. datetime の検出: YYYY[-/] パターンを探す
  let datetime_result = find_datetime(s, pos, parse_datetime)
  match datetime_result {
    Some((dt_epoch_ms, dt_start, dt_end)) => {
      // datetime が見つかった
      // datetime 前の部分を duration としてパース
      let pre_duration_ns = parse_duration_segment(s, pos, dt_start)
      // datetime 後の部分を duration としてパース
      let mut post_start = dt_end
      // 末尾の @ をチェック
      let (end_pos, trailing_at) = check_trailing_at(s, dt_end)
      if trailing_at {
        has_at = true
      }
      // datetime 後の符号を読む
      let (post_negate, post_pos) = read_sign_at(s, post_start)
      post_start = post_pos
      let post_duration_ns = parse_duration_segment(s, post_start, end_pos)
      let post_ns = if post_negate { -post_duration_ns } else { post_duration_ns }
      // 前の duration は符号(negate)に従って加減算
      let pre_ns = if negate { -pre_duration_ns } else { pre_duration_ns }
      let total_offset_ms = (pre_ns + post_ns) / 1_000_000L
      Absolute(dt_epoch_ms + total_offset_ms)
    }
    None => {
      // datetime なし: 全体を duration としてパース
      // 末尾の @ をチェック
      let (end_pos, trailing_at) = check_trailing_at(s, pos)
      if trailing_at {
        has_at = true
      }
      // duration 部分をパース（先頭符号は既に消費済み）
      let duration_str = s[pos:end_pos].to_string()
      if duration_str.length() == 0 {
        raise ParseError("no duration or datetime found in: " + input)
      }
      let duration = parse_duration(duration_str, default_sign=Plus)
      let total_ns = duration.to_ns()
      let signed_ns = if negate { -total_ns } else { total_ns }
      let now_ms = now().reinterpret_as_int64()
      let offset_ms = signed_ns / 1_000_000L
      let epoch_ms = now_ms + offset_ms
      if has_at {
        Absolute(epoch_ms)
      } else {
        Relative(epoch_ms, Duration::from_ns(signed_ns))
      }
    }
  }
}

///| find_datetime: 文字列内から datetime パターン (YYYY[-/]) を検出し、parse_datetime で解決する
fn find_datetime(
  s : StringView,
  start : Int,
  parse_datetime : (String) -> Int64?
) -> (Int64, Int, Int)? {
  let mut pos = start
  while pos < s.length() {
    // 4桁の数字を探す
    if is_four_digits_at(s, pos) {
      // 4桁の後に '-' or '/' があるか確認
      match s.get_char(pos + 4) {
        Some('-') | Some('/') => {
          // datetime の候補: 最長一致で切り出す
          let dt_start = pos
          let dt_end = find_datetime_end(s, pos)
          // 最長から縮めながら parse_datetime を試す
          let result = try_parse_datetime_shrinking(
            s, dt_start, dt_end, parse_datetime,
          )
          match result {
            Some((epoch_ms, actual_end)) =>
              return Some((epoch_ms, dt_start, actual_end))
            None => {
              // datetime として解釈できなかった、次へ進む
              pos += 1
            }
          }
        }
        _ => pos += 1
      }
    } else {
      pos += 1
    }
  }
  None
}

///| is_four_digits_at: 位置 pos から 4桁の ASCII 数字が続くか
fn is_four_digits_at(s : StringView, pos : Int) -> Bool {
  if pos + 4 > s.length() {
    return false
  }
  for i in 0..<4 {
    match s.get_char(pos + i) {
      Some(c) => if Char::is_ascii_digit(c) == false { return false }
      None => return false
    }
  }
  true
}

///| find_datetime_end: datetime として可能な文字列の終端位置を返す（最長一致）
fn find_datetime_end(s : StringView, start : Int) -> Int {
  let mut pos = start
  let mut after_t = false
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if Char::is_ascii_digit(c) ||
          c == '-' ||
          c == '/' ||
          c == 'T' ||
          c == 't' ||
          c == ':' ||
          c == '.' ||
          c == 'Z' ||
          c == 'z' {
          if c == 'T' || c == 't' {
            after_t = true
          }
          pos += 1
        } else if (c == '+' || c == '-') && after_t {
          // TZ オフセットの可能性: 後続が duration unit かチェック
          // +/- 後に数字が続き、その後 h/m/s/w/d 等の duration unit が来たら duration
          let tz_end = probe_tz_offset(s, pos)
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

///| probe_tz_offset: +/- 位置から TZ オフセットとして読めるか調べ、読めた終端位置を返す
fn probe_tz_offset(s : StringView, sign_pos : Int) -> Int {
  // sign_pos は + or - の位置
  let mut pos = sign_pos + 1
  // 数字を読む
  let digit_start = pos
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if Char::is_ascii_digit(c) {
          pos += 1
        } else {
          break
        }
      None => break
    }
  }
  let digit_count = pos - digit_start
  if digit_count == 0 {
    return sign_pos // TZ ではない
  }
  // 数字の後に duration unit (h, m, s, w, d, ms, us, ns) が来たら duration
  match s.get_char(pos) {
    Some('h') | Some('s') | Some('w') | Some('d') => return sign_pos // duration
    Some('m') =>
      match s.get_char(pos + 1) {
        Some('s') => return sign_pos // ms → duration
        Some(c) =>
          if Char::is_ascii_digit(c) == false {
            return sign_pos // m + 非数字 → duration (minutes)
          }
        None => return sign_pos // m at end → duration (minutes)
      }
    Some('u') | Some('n') | Some('\u03BC') => return sign_pos // us/ns/μs → duration
    _ => ()
  }
  // ':' があれば HH:MM パターン
  match s.get_char(pos) {
    Some(':') => {
      pos += 1
      while pos < s.length() {
        match s.get_char(pos) {
          Some(c) =>
            if Char::is_ascii_digit(c) {
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

///| try_parse_datetime_shrinking: 最長一致から縮めながら parse_datetime を試す
fn try_parse_datetime_shrinking(
  s : StringView,
  start : Int,
  max_end : Int,
  parse_datetime : (String) -> Int64?
) -> (Int64, Int)? {
  let mut end = max_end
  while end > start + 7 {
    // 最低限 YYYY-MM-DD (10文字) だが、少し余裕をもつ
    let substr = s[start:end].to_string()
    match parse_datetime(substr) {
      Some(epoch_ms) => return Some((epoch_ms, end))
      None => end -= 1
    }
  }
  None
}

///| parse_duration_segment: 文字列の [start, end) 区間を duration セグメントとしてパース（ns累積を返す）
fn parse_duration_segment(
  s : StringView,
  start : Int,
  end : Int
) -> Int64 raise ParseError {
  let mut pos = skip_spaces(s, start)
  let mut total_ns = 0L
  while pos < end {
    pos = skip_spaces(s, pos)
    if pos >= end {
      break
    }
    // セグメント内符号
    let seg_negate : Bool = match s.get_char(pos) {
      Some('+') => {
        pos += 1
        false
      }
      Some('-') => {
        pos += 1
        true
      }
      _ => false
    }
    pos = skip_spaces(s, pos)
    if pos >= end {
      break
    }
    // 数字が来るはず
    match s.get_char(pos) {
      Some(ch) =>
        if Char::is_ascii_digit(ch) == false {
          // duration セグメントではない — 終了
          break
        }
      None => break
    }
    let (number, new_pos) = parse_number(s, pos)
    pos = new_pos
    pos = skip_spaces(s, pos)
    if pos >= end {
      // 数字の後にユニットがない
      raise ParseError("missing unit after number in timespec")
    }
    let (multiplier, unit_end) = parse_unit(s, pos)
    if unit_end == pos {
      raise ParseError("missing unit after number in timespec")
    }
    pos = unit_end
    let ns_value = (number * multiplier.to_double()).to_int64()
    if seg_negate {
      total_ns -= ns_value
    } else {
      total_ns += ns_value
    }
  }
  total_ns
}

///| check_trailing_at: 末尾（空白を除いた最後）が @ かチェックし、(@ を除いた終端, @ が見つかったか) を返す
fn check_trailing_at(s : StringView, start : Int) -> (Int, Bool) {
  let len = s.length()
  let mut end = len
  // 末尾の空白をスキップ
  while end > start {
    match s.get_char(end - 1) {
      Some(' ') | Some('\t') => end -= 1
      _ => break
    }
  }
  if end > start {
    match s.get_char(end - 1) {
      Some('@') => (end - 1, true)
      _ => (end, false)
    }
  } else {
    (end, false)
  }
}

///| read_sign_at: 位置 pos の符号を読む（+/-/なし）。(negate, 新位置) を返す
fn read_sign_at(s : StringView, pos : Int) -> (Bool, Int) {
  match s.get_char(pos) {
    Some('+') => (false, pos + 1)
    Some('-') => (true, pos + 1)
    _ => (false, pos)
  }
}
