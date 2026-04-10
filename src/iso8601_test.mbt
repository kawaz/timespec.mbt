///|
test "parse_datetime: basic date" {
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024-01-01"),
    content=(
      #|Some(1704067200000)
    ),
  )
}

///|
test "parse_datetime: date with time" {
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024-01-01T12:00:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with time and Z" {
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T12:00:00Z"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with timezone +09:00" {
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T21:00:00+09:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with timezone -05:00" {
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T07:00:00-05:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: slash separator" {
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024/01/01"),
    content=(
      #|Some(1704067200000)
    ),
  )
}

///|
test "parse_datetime: milliseconds" {
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T12:00:00.500Z"),
    content=(
      #|Some(1704110400500)
    ),
  )
}

///|
test "parse_datetime: space separator for T" {
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01 12:00:00Z"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: invalid returns None" {
  debug_inspect(
    @timespec.default_parse_datetime("not-a-date"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @timespec.default_parse_datetime(""),
    content=(
      #|None
    ),
  )
}

///|
test "epoch_to_iso8601: basic UTC" {
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L),
    content=(
      #|"2024-01-01T00:00:00Z"
    ),
  )
}

///|
test "epoch_to_iso8601: with milliseconds" {
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200500L),
    content=(
      #|"2024-01-01T00:00:00.500Z"
    ),
  )
}

///|
test "epoch_to_iso8601: with Hour offset" {
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L, tz_offset=Hour(9)),
    content=(
      #|"2024-01-01T09:00:00+09:00"
    ),
  )
}

///|
test "epoch_to_iso8601: with Min offset" {
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L, tz_offset=Min(330)),
    content=(
      #|"2024-01-01T05:30:00+05:30"
    ),
  )
}

///|
test "epoch_to_iso8601: epoch zero" {
  debug_inspect(
    @timespec.epoch_to_iso8601(0L),
    content=(
      #|"1970-01-01T00:00:00Z"
    ),
  )
}

///|
test "epoch_to_iso8601: TZ offset does not cause Int64 overflow" {
  // Use a large-but-valid epoch (year ~5879610, within Int32 arithmetic range).
  // 185480424979200000 ms ≈ 2146764178 days from epoch.
  // With +01:00 offset (+3600000ms), total_days stays safe (2146764178).
  let large_epoch = 185480424979200000L
  let result_utc = @timespec.epoch_to_iso8601(large_epoch)
  let result_tz = @timespec.epoch_to_iso8601(large_epoch, tz_offset=Hour(1))
  // Both should produce valid far-future dates with positive years
  debug_inspect(result_utc.has_prefix("-"), content="false")
  debug_inspect(result_tz.has_prefix("-"), content="false")
  // Now test values near Int64 boundaries where TZ addition would overflow.
  // Int64.MAX_VALUE - 1000 + Hour(1) offset (+3600000ms) overflows Int64.
  // Without saturating_add: wraps to a large negative, producing a sign-flipped year.
  // With saturating_add: clamps to Int64.MAX_VALUE, avoiding the sign flip.
  // (The output is still garbled by downstream Int32 truncation, but the overflow
  // from TZ addition no longer makes it dramatically worse.)
  let near_max = @int64.MAX_VALUE - 1000L
  let near_max_utc = @timespec.epoch_to_iso8601(near_max)
  let near_max_tz = @timespec.epoch_to_iso8601(near_max, tz_offset=Hour(1))
  // Key invariant: TZ offset addition should not flip the year's sign.
  // Both should have the same sign (both are garbled the same way).
  debug_inspect(
    near_max_utc.has_prefix("-") == near_max_tz.has_prefix("-"),
    content="true",
  )
  // Negative direction: Int64.MIN_VALUE + 1000 with Hour(-1) would underflow.
  let near_min = @int64.MIN_VALUE + 1000L
  let near_min_utc = @timespec.epoch_to_iso8601(near_min)
  let near_min_tz = @timespec.epoch_to_iso8601(near_min, tz_offset=Hour(-1))
  debug_inspect(
    near_min_utc.has_prefix("-") == near_min_tz.has_prefix("-"),
    content="true",
  )
}

///|
test "epoch_to_iso8601: negative epoch (pre-1970)" {
  // 1969-12-31T23:59:59Z = -1000ms
  debug_inspect(
    @timespec.epoch_to_iso8601(-1000L),
    content=(
      #|"1969-12-31T23:59:59Z"
    ),
  )
}

///|
test "datetime normalization: day overflow" {
  // 2026-11-32 → 2026-12-02 (11月は30日)
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-11-32")
  let b = parse_utc("2026-12-02")
  debug_inspect(
    a,
    content=(
      #|Some(1796169600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1796169600000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: month overflow" {
  // 2026-13-01 → 2027-01-01
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-13-01")
  let b = parse_utc("2027-01-01")
  debug_inspect(
    a,
    content=(
      #|Some(1798761600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1798761600000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: second overflow" {
  // 13:50:60 → 13:51:00
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-01-01T13:50:60")
  let b = parse_utc("2026-01-01T13:51:00")
  debug_inspect(
    a,
    content=(
      #|Some(1767275460000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1767275460000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: hour overflow" {
  // 25:00:00 → 翌日 01:00:00
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-01-01T25:00:00")
  let b = parse_utc("2026-01-02T01:00:00")
  debug_inspect(
    a,
    content=(
      #|Some(1767315600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1767315600000)
    ),
  )
  assert_true(a == b)
}

///|
test "epoch_to_iso8601 roundtrip" {
  let epoch = @timespec.default_parse_datetime("2024-06-15T10:30:45Z")
  match epoch {
    Some(ms) =>
      debug_inspect(
        @timespec.epoch_to_iso8601(ms),
        content=(
          #|"2024-06-15T10:30:45Z"
        ),
      )
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
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  // YYYYMMDDTHHmmss
  let b = parse_utc("20260301T120000")
  let c = parse_utc("2026-03-01T12:00:00")
  debug_inspect(
    b,
    content=(
      #|Some(1772366400000)
    ),
  )
  assert_true(b == c)
  // YYYYMMDDTHHmmssZ
  let d = parse_utc("20260301T120000Z")
  assert_true(d == c)
  // YYYYMMDD HHmmss
  let e = parse_utc("20260301 120000")
  assert_true(e == c)
  // YYYYMMDDTHHmm (秒なし)
  let f = parse_utc("20260301T1200")
  let g = parse_utc("2026-03-01T12:00:00")
  assert_true(f == g)
}

///|
test "parse partial datetime: year-only and year-month are rejected" {
  // 部分日付は曖昧さ排除のため拒否（YMD必須）
  debug_inspect(@timespec.default_parse_datetime("2026"), content="None")
  debug_inspect(@timespec.default_parse_datetime("202603"), content="None")
  debug_inspect(@timespec.default_parse_datetime("2026-03"), content="None")
}

///|
test "datetime normalization: month=13 wraps to next year" {
  // 2024-13-01 → 2025-01-01
  let a = @timespec.default_parse_datetime("2024-13-01")
  let b = @timespec.default_parse_datetime("2025-01-01")
  assert_true(a == b)
}

///|
test "datetime normalization: month=0 wraps to previous year" {
  // 2024-00-01 → 2023-12-01
  let a = @timespec.default_parse_datetime("2024-00-01")
  let b = @timespec.default_parse_datetime("2023-12-01")
  assert_true(a == b)
}

///|
test "datetime normalization: Feb 30 in leap year" {
  // 2024年は閏年。2月は29日まで。2024-02-30 → 2024-03-01
  let a = @timespec.default_parse_datetime("2024-02-30")
  let b = @timespec.default_parse_datetime("2024-03-01")
  assert_true(a == b)
}

///|
test "datetime normalization: hour=25" {
  // 2024-01-01T25:00:00Z → 2024-01-02T01:00:00Z
  let a = @timespec.default_parse_datetime("2024-01-01T25:00:00Z")
  let b = @timespec.default_parse_datetime("2024-01-02T01:00:00Z")
  assert_true(a == b)
}

///|
test "datetime normalization: minute=60" {
  // 2024-01-01T12:60:00Z → 2024-01-01T13:00:00Z
  let a = @timespec.default_parse_datetime("2024-01-01T12:60:00Z")
  let b = @timespec.default_parse_datetime("2024-01-01T13:00:00Z")
  assert_true(a == b)
}

///|
test "parse_datetime: empty string returns None" {
  debug_inspect(
    @timespec.default_parse_datetime(""),
    content="None",
  )
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
  debug_inspect(
    i,
    content=(
      #|Some(0)
    ),
  )
}
