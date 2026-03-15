///|
fn test_now() -> UInt64 {
  1_000_000UL  // 1,000,000 ms = 1000 seconds
}

///|
test "parse_timespec: duration only (Relative)" {
  inspect(@src.parse_timespec("5m", now=test_now, default_sign=Minus), content=(
    #|Relative(EpochTime(700000), Duration(-300000))
  ))
}

///|
test "parse_timespec: @ prefix (Absolute)" {
  inspect(@src.parse_timespec("@5m", now=test_now, default_sign=Minus), content=(
    #|Absolute(EpochTime(700000), Duration(-300000))
  ))
}

///|
test "parse_timespec: @ suffix (Absolute)" {
  inspect(@src.parse_timespec("-5h@", now=test_now, default_sign=Minus), content=(
    #|Absolute(EpochTime(-17000000), Duration(-18000000))
  ))
}

///|
test "parse_timespec: @-5h equals -5h@" {
  let a = @src.parse_timespec("@-5h", now=test_now, default_sign=Minus)
  let b = @src.parse_timespec("-5h@", now=test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_timespec: datetime only (Absolute)" {
  inspect(@src.parse_timespec("2024-01-01T12:00:00Z", now=test_now), content=(
    #|Absolute(EpochTime(1704110400000), Duration(0))
  ))
}

///|
test "parse_timespec: datetime + duration" {
  // 2024-01-01T12:00:00Z + 5h30m
  inspect(@src.parse_timespec("2024-01-01T12:00:00Z+5h30m", now=test_now), content=(
    #|Absolute(EpochTime(1704130200000), Duration(19800000))
  ))
}

///|
test "parse_timespec: duration + datetime" {
  // 30m before 2024-01-01T12:00:00Z (default_sign=Plus なので +30m)
  // duration 前の符号は default_sign に従う
  inspect(@src.parse_timespec("30m2024-01-01T12:00:00Z", now=test_now, default_sign=Minus), content=(
    #|Absolute(EpochTime(1704108600000), Duration(-1800000))
  ))
}

///|
test "parse_timespec: duration + datetime + duration" {
  inspect(@src.parse_timespec("30m2024-01-01T12:00:00Z+5h30m", now=test_now, default_sign=Minus), content=(
    #|Absolute(EpochTime(1704128400000), Duration(18000000))
  ))
}

///|
test "parse_timespec: positive duration (Relative)" {
  inspect(@src.parse_timespec("+5m", now=test_now), content=(
    #|Relative(EpochTime(1300000), Duration(300000))
  ))
}

///|
test "parse_timespec: negative duration (Relative)" {
  inspect(@src.parse_timespec("-5m", now=test_now), content=(
    #|Relative(EpochTime(700000), Duration(-300000))
  ))
}

///|
test "parse_timespec: invalid prefix before datetime" {
  let r = try? @src.parse_timespec("xxx2024-01-01T12:00:00Z", now=test_now)
  assert_true(r is Err(_))
}

///|
test "parse_timespec: garbage after datetime" {
  let r = try? @src.parse_timespec("2024-01-01Zgarbage", now=test_now)
  assert_true(r is Err(_))
}

///|
test "parse_timespec: Reject with datetime (no error)" {
  // datetime 入力は符号不要
  inspect(@src.parse_timespec("2024-01-01T12:00:00Z", now=test_now, default_sign=Reject), content=(
    #|Absolute(EpochTime(1704110400000), Duration(0))
  ))
}

///|
test "parse_timespec: Reject with unsigned duration (error)" {
  let r = try? @src.parse_timespec("5m", now=test_now, default_sign=Reject)
  assert_true(r is Err(_))
}

///|
test "parse_timespec: custom epoch (Snowflake)" {
  let snowflake_epoch = @src.EpochTime(1288834974657L)
  // now = 1_700_000_000_000 (Unix ms) → Snowflake relative = 1_700_000_000_000 - 1_288_834_974_657 = 411_165_025_343
  let now_fn = fn() -> UInt64 { 1_700_000_000_000UL }
  let ts = @src.parse_timespec("0s", epoch=snowflake_epoch, now=now_fn)
  // epoch relative の now
  inspect(ts, content=(
    #|Relative(EpochTime(411165025343), Duration(0))
  ))
}

///|
test "parse_timespec: default epoch is Unix" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let a = @src.parse_timespec("5m", epoch=@src.EpochTime(0L), now=now_fn, default_sign=Minus)
  let b = @src.parse_timespec("5m", now=now_fn, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_timespec: custom epoch with datetime" {
  let snowflake_epoch = @src.EpochTime(1288834974657L)
  let now_fn = fn() -> UInt64 { 1_700_000_000_000UL }
  // datetime "2024-01-01T12:00:00Z" = 1704110400000 Unix ms
  // epoch relative = 1704110400000 - 1288834974657 = 415275425343
  let ts = @src.parse_timespec("2024-01-01T12:00:00Z", epoch=snowflake_epoch, now=now_fn)
  inspect(ts, content=(
    #|Absolute(EpochTime(415275425343), Duration(0))
  ))
}

///|
test "parse_timespec: @ position equivalence" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let a = @src.parse_timespec("@1h30m", now=now_fn, default_sign=Minus)
  let b = @src.parse_timespec("1h@30m", now=now_fn, default_sign=Minus)
  let c = @src.parse_timespec("1h30m@", now=now_fn, default_sign=Minus)
  assert_true(a == b)
  assert_true(b == c)
}

///|
test "parse_timespec: time-of-day reset @00:00" {
  let now_fn = fn() -> UInt64 { 1_000_000_000UL } // some now
  let ts = @src.parse_timespec("@00:00", now=now_fn, default_tz_offset=Utc)
  // should be today's midnight UTC
  inspect(ts, content=(
    #|Absolute(EpochTime(950400000), Duration(0))
  ))
}

///|
test "parse_timespec: time-of-day @10:30" {
  let now_fn = fn() -> UInt64 { 1_000_000_000UL }
  let ts = @src.parse_timespec("@10:30", now=now_fn, default_tz_offset=Utc)
  inspect(ts, content=(
    #|Absolute(EpochTime(988200000), Duration(0))
  ))
}

///|
test "parse_timespec: time-of-day with duration @00:00+3h" {
  let now_fn = fn() -> UInt64 { 1_000_000_000UL }
  let ts = @src.parse_timespec(
    "@00:00+3h", now=now_fn, default_tz_offset=Utc, default_sign=Plus,
  )
  inspect(ts, content=(
    #|Absolute(EpochTime(961200000), Duration(10800000))
  ))
}

///|
test "parse_timespec: raw epoch ms (@DIGITS)" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  // @1704110400000 → EpochTime(1704110400000) = 2024-01-01T12:00:00Z
  let ts = @src.parse_timespec("@1704110400000", now=now_fn)
  inspect(ts, content=(
    #|Absolute(EpochTime(1704110400000), Duration(0))
  ))
}

///|
test "parse_timespec: raw epoch ms with duration" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  // @1704110400000+1h → EpochTime(1704110400000 + 3600000)
  let ts = @src.parse_timespec("@1704110400000+1h", now=now_fn)
  inspect(ts, content=(
    #|Absolute(EpochTime(1704114000000), Duration(3600000))
  ))
}

///|
test "parse_timespec: @2026 is raw epoch not year" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let ts = @src.parse_timespec("@2026", now=now_fn)
  // 2026ms from epoch, NOT 2026-01-01
  inspect(ts, content=(
    #|Absolute(EpochTime(2026), Duration(0))
  ))
}

///|
test "parse_timespec: @-100 negative raw epoch" {
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let ts = @src.parse_timespec("@-100", now=now_fn)
  // 100ms before epoch
  inspect(ts, content=(
    #|Absolute(EpochTime(-100), Duration(0))

  ))
}
