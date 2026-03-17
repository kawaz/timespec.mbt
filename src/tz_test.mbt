///|
test "parse_tz_offset: empty and UTC/GMT variants" {
  inspect(@timespec.parse_tz_offset(""), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("Z"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("UTC"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("GMT"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("gmt"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: hour only" {
  inspect(@timespec.parse_tz_offset("9"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("+9"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("+09"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("-5"), content=(
    #|Hour(-5)
  ))
}

///|
test "parse_tz_offset: HHMM and HH:MM" {
  inspect(@timespec.parse_tz_offset("+0900"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("+09:00"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("+0530"), content=(
    #|Min(330)
  ))
  inspect(@timespec.parse_tz_offset("+05:30"), content=(
    #|Min(330)
  ))
}

///|
test "parse_tz_offset: duration format" {
  inspect(@timespec.parse_tz_offset("5h30m"), content=(
    #|Min(330)
  ))
  inspect(@timespec.parse_tz_offset("+5h30m"), content=(
    #|Min(330)
  ))
  inspect(@timespec.parse_tz_offset("-5h"), content=(
    #|Hour(-5)
  ))
  inspect(@timespec.parse_tz_offset("9h"), content=(
    #|Hour(9)
  ))
}

///|
test "parse_tz_offset: zero offset" {
  inspect(@timespec.parse_tz_offset("0"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("+0"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("-00:00"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: negative minutes" {
  inspect(@timespec.parse_tz_offset("-5:30"), content=(
    #|Min(-330)
  ))
  inspect(@timespec.parse_tz_offset("-0530"), content=(
    #|Min(-330)
  ))
}

///|
test "parse_tz_offset: lowercase z" {
  inspect(@timespec.parse_tz_offset("z"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: case-insensitive UTC" {
  inspect(@timespec.parse_tz_offset("utc"), content=(
    #|Utc
  ))
  inspect(@timespec.parse_tz_offset("Utc"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: GMT+offset" {
  inspect(@timespec.parse_tz_offset("GMT+9"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("GMT+0900"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("GMT+09:00"), content=(
    #|Hour(9)
  ))
  inspect(@timespec.parse_tz_offset("GMT-5"), content=(
    #|Hour(-5)
  ))
  inspect(@timespec.parse_tz_offset("UTC+5:30"), content=(
    #|Min(330)
  ))
}

///|
test "parse_tz_offset: trailing garbage error" {
  let r = try? @timespec.parse_tz_offset("+09:00abc")
  assert_true(r is Err(_))
}

///|
test "parse_tz_offset: seconds not valid as tz" {
  let r = try? @timespec.parse_tz_offset("30s")
  assert_true(r is Err(_))
}

///|
test "parse_tz_offset: local" {
  inspect(@timespec.parse_tz_offset("local"), content=(
    #|Local
  ))
  inspect(@timespec.parse_tz_offset("LOCAL"), content=(
    #|Local
  ))
  inspect(@timespec.parse_tz_offset("Local"), content=(
    #|Local
  ))
}

///|
test "local_tz_offset returns valid TzOffset" {
  let tz = @timespec.local_tz_offset()
  // local_tz_offset は Local を返さない（解決済みの値を返す）
  match tz {
    Utc => ()
    Hour(_) => ()
    Min(_) => ()
    Local => assert_true(false)
  }
}

///|
test "parse_tz_offset: boundary values" {
  // 有効な範囲の端
  inspect(@timespec.parse_tz_offset("+14"), content=(
    #|Hour(14)
  ))
  inspect(@timespec.parse_tz_offset("-12"), content=(
    #|Hour(-12)
  ))
  inspect(@timespec.parse_tz_offset("+24"), content=(
    #|Hour(24)
  ))
  inspect(@timespec.parse_tz_offset("-24"), content=(
    #|Hour(-24)
  ))
}

///|
test "parse_tz_offset: out of range error" {
  let r1 = try? @timespec.parse_tz_offset("+25")
  assert_true(r1 is Err(_))
  let r2 = try? @timespec.parse_tz_offset("-25")
  assert_true(r2 is Err(_))
  let r3 = try? @timespec.parse_tz_offset("+99")
  assert_true(r3 is Err(_))
}
