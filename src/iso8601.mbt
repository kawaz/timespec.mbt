///| default_parse_datetime: ISO 8601 文字列をパースし epoch_ms を返す。パース失敗は None
pub fn default_parse_datetime(input : String) -> Int64? {
  try {
    Some(parse_iso8601(input))
  } catch {
    _ => None
  }
}

///| parse_iso8601: ISO 8601 文字列をパースし epoch_ms を返す
fn parse_iso8601(input : String) -> Int64 raise ParseError {
  let s = input.trim()
  if s.length() == 0 {
    raise ParseError("empty datetime string")
  }
  let mut pos = 0
  // 年(4桁)
  let (year, p1) = parse_int_digits(s, pos, 4, 4)
  pos = p1
  // 区切り '-' or '/'
  pos = skip_date_sep(s, pos)
  // 月(1-2桁)
  let (month, p2) = parse_int_digits(s, pos, 1, 2)
  pos = p2
  // 区切り '-' or '/'
  pos = skip_date_sep(s, pos)
  // 日(1-2桁)
  let (day, p3) = parse_int_digits(s, pos, 1, 2)
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
        // ':'
        pos = skip_time_sep(s, pos)
        // 分(1-2桁)
        let (m, p5) = parse_int_digits(s, pos, 1, 2)
        min = m
        pos = p5
        // ':'
        pos = skip_time_sep(s, pos)
        // 秒(1-2桁)
        let (sc, p6) = parse_int_digits(s, pos, 1, 2)
        sec = sc
        pos = p6
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
  let mut tz_offset_min = 0
  if pos < s.length() {
    match s.get_char(pos) {
      Some('Z') | Some('z') => {
        pos += 1
        tz_offset_min = 0
      }
      Some('+') | Some('-') => {
        let sign : Int = match s.get_char(pos) {
          Some('+') => 1
          _ => -1
        }
        pos += 1
        let (tz_h, p8) = parse_int_digits(s, pos, 1, 2)
        pos = p8
        let mut tz_m = 0
        if pos < s.length() {
          match s.get_char(pos) {
            Some(':') => {
              pos += 1
              let (m, p9) = parse_int_digits(s, pos, 1, 2)
              tz_m = m
              pos = p9
            }
            Some(c) =>
              if Char::is_ascii_digit(c) {
                let (m, p9) = parse_int_digits(s, pos, 2, 2)
                tz_m = m
                pos = p9
              }
            None => ()
          }
        }
        tz_offset_min = sign * (tz_h * 60 + tz_m)
      }
      _ => ()
    }
  }
  // 末尾に余分な文字がないか確認
  if pos < s.length() {
    raise ParseError(
      "unexpected character at position " + pos.to_string() + " in: " + input,
    )
  }
  let epoch = datetime_to_epoch(year, month, day, hour, min, sec, ms)
  // TZ オフセットを減算して UTC に変換
  epoch - tz_offset_min.to_int64() * 60L * 1000L
}

///| parse_int_digits: 指定桁数の整数をパースする
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
        if Char::is_ascii_digit(c) {
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

///| parse_frac_digits: 小数部をパースする。最大 max_digits 桁まで読み、(値, 読んだ桁数, 新位置) を返す
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
        if Char::is_ascii_digit(c) {
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
        if Char::is_ascii_digit(c) {
          pos += 1
        } else {
          break
        }
      None => break
    }
  }
  (value, count, pos)
}

///| skip_date_sep: 日付区切り文字('-' or '/')をスキップ
fn skip_date_sep(s : StringView, pos : Int) -> Int {
  match s.get_char(pos) {
    Some('-') | Some('/') => pos + 1
    _ => pos
  }
}

///| skip_time_sep: 時刻区切り文字(':')をスキップ
fn skip_time_sep(s : StringView, pos : Int) -> Int {
  match s.get_char(pos) {
    Some(':') => pos + 1
    _ => pos
  }
}

///| datetime_to_epoch: 日付時刻を正規化し epoch_ms に変換（Go mktime スタイル）
fn datetime_to_epoch(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  min : Int,
  sec : Int,
  ms : Int
) -> Int64 {
  let mut y = year
  let mut mo = month
  let mut d = day
  let mut h = hour
  let mut mi = min
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

///| days_from_epoch: 1970-01-01 からの通算日数を計算
fn days_from_epoch(year : Int, month : Int, day : Int) -> Int {
  // 年の通算日数
  let mut days = 0
  if year >= 1970 {
    for yr in 1970..<year {
      days += if is_leap_year(yr) { 366 } else { 365 }
    }
  } else {
    for yr in year..<1970 {
      days -= if is_leap_year(yr) { 366 } else { 365 }
    }
  }
  // 月の通算日数
  for m in 1..<month {
    days += days_in_month(year, m)
  }
  // 日を加算
  days + day - 1
}

///| days_in_month: 月の日数（うるう年対応）
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

///| is_leap_year: うるう年判定
fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///| epoch_to_iso8601: epoch_ms を ISO 8601 文字列に変換
pub fn epoch_to_iso8601(
  epoch_ms : Int64,
  tz~ : TzOffset = Utc
) -> String raise ParseError {
  match tz {
    Local =>
      raise ParseError("Local timezone is not supported yet (requires FFI)")
    _ => ()
  }
  // TzOffset に応じて epoch_ms にオフセットを加算
  let offset_min : Int = match tz {
    Utc => 0
    Hour(h) => h * 60
    Min(m) => m
    Local => 0 // unreachable
  }
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
  // total_days から年月日を逆算（1970-01-01 = day 0）
  let mut year = 1970
  if total_days >= 0 {
    while true {
      let dy = if is_leap_year(year) { 366 } else { 365 }
      if total_days < dy {
        break
      }
      total_days -= dy
      year += 1
    }
  } else {
    while total_days < 0 {
      year -= 1
      let dy = if is_leap_year(year) { 366 } else { 365 }
      total_days += dy
    }
  }
  let mut month = 1
  while true {
    let dm = days_in_month(year, month)
    if total_days < dm {
      break
    }
    total_days -= dm
    month += 1
  }
  let day = total_days + 1
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
  match tz {
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

///| pad2: 2桁ゼロ埋め
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///| pad3: 3桁ゼロ埋め
fn pad3(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///| pad4: 4桁ゼロ埋め（年用）
fn pad4(n : Int) -> String {
  if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///| floor_div: 負値対応の整数除算（Python 式）
fn floor_div(a : Int, b : Int) -> Int {
  if (a >= 0) == (b > 0) {
    a / b
  } else {
    (a - b + 1) / b
  }
}

///| floor_mod: 負値対応の剰余（Python 式）
fn floor_mod(a : Int, b : Int) -> Int {
  a - floor_div(a, b) * b
}
