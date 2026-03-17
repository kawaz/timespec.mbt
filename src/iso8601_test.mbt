///|
test "parse_datetime: basic date" {
  inspect(@timespec.default_parse_datetime("2024-01-01"), content=(
    #|Some(1704067200000)
  ))
}

///|
test "parse_datetime: date with time" {
  inspect(@timespec.default_parse_datetime("2024-01-01T12:00:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with time and Z" {
  inspect(@timespec.default_parse_datetime("2024-01-01T12:00:00Z"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with timezone +09:00" {
  inspect(@timespec.default_parse_datetime("2024-01-01T21:00:00+09:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with timezone -05:00" {
  inspect(@timespec.default_parse_datetime("2024-01-01T07:00:00-05:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: slash separator" {
  inspect(@timespec.default_parse_datetime("2024/01/01"), content=(
    #|Some(1704067200000)
  ))
}

///|
test "parse_datetime: milliseconds" {
  inspect(@timespec.default_parse_datetime("2024-01-01T12:00:00.500Z"), content=(
    #|Some(1704110400500)
  ))
}

///|
test "parse_datetime: space separator for T" {
  inspect(@timespec.default_parse_datetime("2024-01-01 12:00:00Z"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: invalid returns None" {
  inspect(@timespec.default_parse_datetime("not-a-date"), content=(
    #|None
  ))
  inspect(@timespec.default_parse_datetime(""), content=(
    #|None
  ))
}

///|
test "epoch_to_iso8601: basic UTC" {
  inspect(@timespec.epoch_to_iso8601(1704067200000L), content=(
    #|2024-01-01T00:00:00Z
  ))
}

///|
test "epoch_to_iso8601: with milliseconds" {
  inspect(@timespec.epoch_to_iso8601(1704067200500L), content=(
    #|2024-01-01T00:00:00.500Z
  ))
}

///|
test "epoch_to_iso8601: with Hour offset" {
  inspect(@timespec.epoch_to_iso8601(1704067200000L, tz_offset=Hour(9)), content=(
    #|2024-01-01T09:00:00+09:00
  ))
}

///|
test "epoch_to_iso8601: with Min offset" {
  inspect(@timespec.epoch_to_iso8601(1704067200000L, tz_offset=Min(330)), content=(
    #|2024-01-01T05:30:00+05:30
  ))
}

///|
test "epoch_to_iso8601: epoch zero" {
  inspect(@timespec.epoch_to_iso8601(0L), content=(
    #|1970-01-01T00:00:00Z
  ))
}

///|
test "epoch_to_iso8601: negative epoch (pre-1970)" {
  // 1969-12-31T23:59:59Z = -1000ms
  inspect(@timespec.epoch_to_iso8601(-1000L), content=(
    #|1969-12-31T23:59:59Z
  ))
}

///|
test "datetime normalization: day overflow" {
  // 2026-11-32 → 2026-12-02 (11月は30日)
  let a = @timespec.default_parse_datetime("2026-11-32")
  let b = @timespec.default_parse_datetime("2026-12-02")
  inspect(a, content=(
    #|Some(1796169600000)
  ))
  inspect(b, content=(
    #|Some(1796169600000)
  ))
  assert_true(a == b)
}

///|
test "datetime normalization: month overflow" {
  // 2026-13-01 → 2027-01-01
  let a = @timespec.default_parse_datetime("2026-13-01")
  let b = @timespec.default_parse_datetime("2027-01-01")
  inspect(a, content=(
    #|Some(1798761600000)
  ))
  inspect(b, content=(
    #|Some(1798761600000)
  ))
  assert_true(a == b)
}

///|
test "datetime normalization: second overflow" {
  // 13:50:60 → 13:51:00
  let a = @timespec.default_parse_datetime("2026-01-01T13:50:60")
  let b = @timespec.default_parse_datetime("2026-01-01T13:51:00")
  inspect(a, content=(
    #|Some(1767275460000)
  ))
  inspect(b, content=(
    #|Some(1767275460000)
  ))
  assert_true(a == b)
}

///|
test "datetime normalization: hour overflow" {
  // 25:00:00 → 翌日 01:00:00
  let a = @timespec.default_parse_datetime("2026-01-01T25:00:00")
  let b = @timespec.default_parse_datetime("2026-01-02T01:00:00")
  inspect(a, content=(
    #|Some(1767315600000)
  ))
  inspect(b, content=(
    #|Some(1767315600000)
  ))
  assert_true(a == b)
}

///|
test "epoch_to_iso8601 roundtrip" {
  let epoch = @timespec.default_parse_datetime("2024-06-15T10:30:45Z")
  match epoch {
    Some(ms) => inspect(@timespec.epoch_to_iso8601(ms), content=(
      #|2024-06-15T10:30:45Z
    ))
    None => assert_true(false)
  }
}

///|
test "parse flexible date formats" {
  // 1-2桁の月日
  let a = @timespec.default_parse_datetime("2026-3-1")
  let b = @timespec.default_parse_datetime("2026-03-01")
  assert_true(a == b)
  // スラッシュ + 1桁
  let c = @timespec.default_parse_datetime("2026/3/1")
  assert_true(a == c)
  // 1桁時分秒
  let d = @timespec.default_parse_datetime("2026-3-1T9:5:3")
  let e = @timespec.default_parse_datetime("2026-03-01T09:05:03")
  assert_true(d == e)
  // 区切りなし (YYYYMMDD)
  let f = @timespec.default_parse_datetime("20260301")
  assert_true(a == f)
}

///|
test "parse compact datetime formats" {
  // YYYYMMDDTHHmmss
  let b = @timespec.default_parse_datetime("20260301T120000")
  let c = @timespec.default_parse_datetime("2026-03-01T12:00:00")
  inspect(b, content=(
    #|Some(1772366400000)
  ))
  assert_true(b == c)
  // YYYYMMDDTHHmmssZ
  let d = @timespec.default_parse_datetime("20260301T120000Z")
  assert_true(d == c)
  // YYYYMMDD HHmmss
  let e = @timespec.default_parse_datetime("20260301 120000")
  assert_true(e == c)
  // YYYYMMDDTHHmm (秒なし)
  let f = @timespec.default_parse_datetime("20260301T1200")
  let g = @timespec.default_parse_datetime("2026-03-01T12:00:00")
  assert_true(f == g)
}

///|
test "parse partial datetime: year-only and year-month are rejected" {
  // 部分日付は曖昧さ排除のため拒否（YMD必須）
  inspect(@timespec.default_parse_datetime("2026"), content="None")
  inspect(@timespec.default_parse_datetime("202603"), content="None")
  inspect(@timespec.default_parse_datetime("2026-03"), content="None")
}

///|
test "parse time-only formats" {
  // HH:MM
  let a = @timespec.default_parse_datetime("10:30")
  let b = @timespec.default_parse_datetime("1970-01-01T10:30:00")
  assert_true(a == b)
  // HH:MM:SS
  let c = @timespec.default_parse_datetime("10:30:45")
  let d = @timespec.default_parse_datetime("1970-01-01T10:30:45")
  assert_true(c == d)
  // HH:MM:SS.mmm
  let e = @timespec.default_parse_datetime("10:30:45.500")
  let f = @timespec.default_parse_datetime("1970-01-01T10:30:45.500")
  assert_true(e == f)
  // HH:MM with TZ
  let g = @timespec.default_parse_datetime("10:30+09:00")
  let h = @timespec.default_parse_datetime("1970-01-01T10:30:00+09:00")
  assert_true(g == h)
  // 00:00Z
  let i = @timespec.default_parse_datetime("00:00Z")
  inspect(i, content=(
    #|Some(0)
  ))
}
