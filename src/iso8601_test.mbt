///|
test "parse_datetime: basic date" {
  inspect(@src.default_parse_datetime("2024-01-01"), content=(
    #|Some(1704067200000)
  ))
}

///|
test "parse_datetime: date with time" {
  inspect(@src.default_parse_datetime("2024-01-01T12:00:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with time and Z" {
  inspect(@src.default_parse_datetime("2024-01-01T12:00:00Z"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with timezone +09:00" {
  inspect(@src.default_parse_datetime("2024-01-01T21:00:00+09:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: date with timezone -05:00" {
  inspect(@src.default_parse_datetime("2024-01-01T07:00:00-05:00"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: slash separator" {
  inspect(@src.default_parse_datetime("2024/01/01"), content=(
    #|Some(1704067200000)
  ))
}

///|
test "parse_datetime: milliseconds" {
  inspect(@src.default_parse_datetime("2024-01-01T12:00:00.500Z"), content=(
    #|Some(1704110400500)
  ))
}

///|
test "parse_datetime: space separator for T" {
  inspect(@src.default_parse_datetime("2024-01-01 12:00:00Z"), content=(
    #|Some(1704110400000)
  ))
}

///|
test "parse_datetime: invalid returns None" {
  inspect(@src.default_parse_datetime("not-a-date"), content=(
    #|None
  ))
  inspect(@src.default_parse_datetime(""), content=(
    #|None
  ))
}

///|
test "epoch_to_iso8601: basic UTC" {
  inspect(@src.epoch_to_iso8601(1704067200000L), content=(
    #|2024-01-01T00:00:00Z
  ))
}

///|
test "epoch_to_iso8601: with milliseconds" {
  inspect(@src.epoch_to_iso8601(1704067200500L), content=(
    #|2024-01-01T00:00:00.500Z
  ))
}

///|
test "epoch_to_iso8601: with Hour offset" {
  inspect(@src.epoch_to_iso8601(1704067200000L, tz=Hour(9)), content=(
    #|2024-01-01T09:00:00+09:00
  ))
}

///|
test "epoch_to_iso8601: with Min offset" {
  inspect(@src.epoch_to_iso8601(1704067200000L, tz=Min(330)), content=(
    #|2024-01-01T05:30:00+05:30
  ))
}

///|
test "epoch_to_iso8601: epoch zero" {
  inspect(@src.epoch_to_iso8601(0L), content=(
    #|1970-01-01T00:00:00Z
  ))
}

///|
test "epoch_to_iso8601: negative epoch (pre-1970)" {
  // 1969-12-31T23:59:59Z = -1000ms
  inspect(@src.epoch_to_iso8601(-1000L), content=(
    #|1969-12-31T23:59:59Z
  ))
}

///|
test "datetime normalization: day overflow" {
  // 2026-11-32 → 2026-12-02 (11月は30日)
  let a = @src.default_parse_datetime("2026-11-32")
  let b = @src.default_parse_datetime("2026-12-02")
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
  let a = @src.default_parse_datetime("2026-13-01")
  let b = @src.default_parse_datetime("2027-01-01")
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
  let a = @src.default_parse_datetime("2026-01-01T13:50:60")
  let b = @src.default_parse_datetime("2026-01-01T13:51:00")
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
  let a = @src.default_parse_datetime("2026-01-01T25:00:00")
  let b = @src.default_parse_datetime("2026-01-02T01:00:00")
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
  let epoch = @src.default_parse_datetime("2024-06-15T10:30:45Z")
  match epoch {
    Some(ms) => inspect(@src.epoch_to_iso8601(ms), content=(
      #|2024-06-15T10:30:45Z
    ))
    None => assert_true(false)
  }
}
