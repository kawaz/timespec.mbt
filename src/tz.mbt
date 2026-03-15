///| parse_tz_offset: タイムゾーンオフセット文字列をパースする
pub fn parse_tz_offset(input : String) -> TzOffset raise ParseError {
  let s = input.trim()
  let len = s.length()
  if len == 0 {
    return Utc
  }
  // Z → Utc
  if len == 1 {
    match s.get_char(0) {
      Some('Z') => return Utc
      _ => ()
    }
  }
  // UTC → Utc
  if len == 3 {
    match (s.get_char(0), s.get_char(1), s.get_char(2)) {
      (Some('U'), Some('T'), Some('C')) => return Utc
      _ => ()
    }
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
    let ms = match dur {
      Ms(ms) => ms
      MsNs(ms, _) => ms
    }
    (ms / 60_000L).to_int()
  } else {
    // 数値形式のパース
    parse_numeric_offset(s, pos, sign)
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

///| contains_duration_unit: pos 以降に duration ユニット文字 (h, m, s) が含まれるか
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

///| parse_numeric_offset: 数値形式のオフセットをパース (HH, HHMM, HH:MM)
fn parse_numeric_offset(
  s : StringView,
  start : Int,
  sign : Int
) -> Int raise ParseError {
  let mut pos = start
  // 最初の数値部分を読む
  let mut first_num = 0
  let mut first_digits = 0
  while pos < s.length() {
    match s.get_char(pos) {
      Some(c) =>
        if Char::is_ascii_digit(c) {
          first_num = first_num * 10 + (c.to_int() - '0'.to_int())
          first_digits += 1
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
            if Char::is_ascii_digit(c) {
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
      sign * (first_num * 60 + mm)
    }
    _ =>
      if first_digits <= 2 {
        // 1-2桁: 時のみ
        sign * first_num * 60
      } else if first_digits == 4 {
        // 4桁: HHMM
        let hh = first_num / 100
        let mm = first_num % 100
        sign * (hh * 60 + mm)
      } else {
        raise ParseError("invalid timezone offset format")
      }
  }
}
