///|
fn test_now() -> UInt64 {
  1_000_000UL  // 1,000,000 ms = 1000 seconds
}

///|
test "parse_timespec: duration only (Relative)" {
  inspect(@src.parse_timespec("5m", now=test_now, default_sign=Minus), content=(
    #|Relative(700000, Ms(-300000))
  ))
}

///|
test "parse_timespec: @ prefix (Absolute)" {
  inspect(@src.parse_timespec("@5m", now=test_now, default_sign=Minus), content=(
    #|Absolute(700000)
  ))
}

///|
test "parse_timespec: @ suffix (Absolute)" {
  inspect(@src.parse_timespec("-5h@", now=test_now, default_sign=Minus), content=(
    #|Absolute(-17000000)
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
    #|Absolute(1704110400000)
  ))
}

///|
test "parse_timespec: datetime + duration" {
  // 2024-01-01T12:00:00Z + 5h30m
  inspect(@src.parse_timespec("2024-01-01T12:00:00Z+5h30m", now=test_now), content=(
    #|Absolute(1704130200000)
  ))
}

///|
test "parse_timespec: duration + datetime" {
  // 30m before 2024-01-01T12:00:00Z (default_sign=Plus なので +30m)
  // duration 前の符号は default_sign に従う
  inspect(@src.parse_timespec("30m2024-01-01T12:00:00Z", now=test_now, default_sign=Minus), content=(
    #|Absolute(1704108600000)
  ))
}

///|
test "parse_timespec: duration + datetime + duration" {
  inspect(@src.parse_timespec("30m2024-01-01T12:00:00Z+5h30m", now=test_now, default_sign=Minus), content=(
    #|Absolute(1704128400000)
  ))
}

///|
test "parse_timespec: positive duration (Relative)" {
  inspect(@src.parse_timespec("+5m", now=test_now), content=(
    #|Relative(1300000, Ms(300000))
  ))
}

///|
test "parse_timespec: negative duration (Relative)" {
  inspect(@src.parse_timespec("-5m", now=test_now), content=(
    #|Relative(700000, Ms(-300000))
  ))
}
