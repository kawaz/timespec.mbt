///| from_ns: ナノ秒から Duration を生成（floor division で正規化）
pub fn Duration::from_ns(total_ns : Int64) -> Duration {
  if total_ns == 0L {
    Ms(0L)
  } else {
    let ns_per_ms = 1_000_000L
    // floor division: ms 部分は切り捨て方向
    let mut ms = total_ns / ns_per_ms
    let mut ns = (total_ns % ns_per_ms).to_int()
    if ns < 0 {
      ms -= 1L
      ns += 1_000_000
    }
    if ns == 0 {
      Ms(ms)
    } else {
      MsNs(ms, ns)
    }
  }
}

///| to_ns: Duration をナノ秒に変換
pub fn Duration::to_ns(self : Duration) -> Int64 {
  match self {
    Ms(ms) => ms * 1_000_000L
    MsNs(ms, ns) => ms * 1_000_000L + ns.to_int64()
  }
}

///| parse_duration: Duration 文字列をパースする
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
  // セグメントを繰り返しパース
  let mut total_ns = 0L
  let mut parsed_any = false
  while pos < s.length() {
    // スペースをスキップ
    pos = skip_spaces(s, pos)
    if pos >= s.length() {
      break
    }
    // セグメント内符号を判定
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
    if pos >= s.length() {
      break
    }
    // 数値を読む
    match s.get_char(pos) {
      Some(ch) =>
        if Char::is_ascii_digit(ch) == false {
          raise ParseError(
            "expected digit at position " + pos.to_string() + " in: " + input,
          )
        }
      None => break
    }
    let (number, new_pos) = parse_number(s, pos)
    pos = new_pos
    pos = skip_spaces(s, pos)
    // ユニットを読む
    let (multiplier, unit_end) = parse_unit(s, pos)
    if unit_end == pos {
      raise ParseError("missing unit after number in: " + input)
    }
    pos = unit_end
    let ns_value = (number * multiplier.to_double()).to_int64()
    if seg_negate {
      total_ns -= ns_value
    } else {
      total_ns += ns_value
    }
    parsed_any = true
  }
  if parsed_any == false {
    raise ParseError("no duration segments found in: " + input)
  }
  if negate {
    total_ns = -total_ns
  }
  Duration::from_ns(total_ns)
}

///| skip_spaces: 空白文字をスキップし、新しい位置を返す
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

///| parse_number: 整数部と小数部を含む数値をパースする。アンダースコア区切り対応
fn parse_number(s : StringView, start : Int) -> (Double, Int) {
  let mut pos = start
  let mut integer_part = 0.0
  // 整数部
  while pos < s.length() {
    match s.get_char(pos) {
      Some('_') => pos += 1
      Some(c) =>
        if Char::is_ascii_digit(c) {
          integer_part = integer_part * 10.0 + (c.to_int() - '0'.to_int()).to_double()
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
            if Char::is_ascii_digit(c) {
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
  (integer_part + frac_part, pos)
}

///| parse_unit: 位置 pos からユニット文字列を読み取り、ns 単位の乗数と終了位置を返す
fn parse_unit(
  s : StringView,
  pos : Int
) -> (Int64, Int) raise ParseError {
  match s.get_char(pos) {
    Some('w') => (604_800_000_000_000L, pos + 1)
    Some('d') => (86_400_000_000_000L, pos + 1)
    Some('h') => (3_600_000_000_000L, pos + 1)
    Some('m') =>
      // 'm' の次が 's' なら ms（ミリ秒）
      match s.get_char(pos + 1) {
        Some('s') => (1_000_000L, pos + 2)
        _ => (60_000_000_000L, pos + 1)
      }
    Some('s') => (1_000_000_000L, pos + 1)
    Some('u') =>
      match s.get_char(pos + 1) {
        Some('s') => (1_000L, pos + 2)
        _ =>
          raise ParseError(
            "unknown unit 'u' at position " +
            pos.to_string() +
            " (did you mean 'us'?)",
          )
      }
    Some('\u03BC') =>
      // μ (U+03BC)
      match s.get_char(pos + 1) {
        Some('s') => (1_000L, pos + 2)
        _ =>
          raise ParseError(
            "unknown unit '\u03BC' at position " +
            pos.to_string() +
            " (did you mean '\u03BCs'?)",
          )
      }
    Some('n') =>
      match s.get_char(pos + 1) {
        Some('s') => (1L, pos + 2)
        _ =>
          raise ParseError(
            "unknown unit 'n' at position " +
            pos.to_string() +
            " (did you mean 'ns'?)",
          )
      }
    Some(c) =>
      raise ParseError(
        "unknown unit '" + c.to_string() + "' at position " + pos.to_string(),
      )
    None => (0L, pos) // no unit found
  }
}
