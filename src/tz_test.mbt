///|
test "parse_tz_offset: empty and UTC/GMT variants" {
  debug_inspect(
    @timespec.parse_tz_offset(""),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Z"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("UTC"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("gmt"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: hour only" {
  debug_inspect(
    @timespec.parse_tz_offset("9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+09"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-5"),
    content=(
      #|Hour(-5)
    ),
  )
}

///|
test "parse_tz_offset: HHMM and HH:MM" {
  debug_inspect(
    @timespec.parse_tz_offset("+0900"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+09:00"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+0530"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+05:30"),
    content=(
      #|Min(330)
    ),
  )
}

///|
test "parse_tz_offset: duration format" {
  debug_inspect(
    @timespec.parse_tz_offset("5h30m"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+5h30m"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-5h"),
    content=(
      #|Hour(-5)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("9h"),
    content=(
      #|Hour(9)
    ),
  )
}

///|
test "parse_tz_offset: zero offset" {
  debug_inspect(
    @timespec.parse_tz_offset("0"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+0"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-00:00"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: negative minutes" {
  debug_inspect(
    @timespec.parse_tz_offset("-5:30"),
    content=(
      #|Min(-330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-0530"),
    content=(
      #|Min(-330)
    ),
  )
}

///|
test "parse_tz_offset: lowercase z" {
  debug_inspect(
    @timespec.parse_tz_offset("z"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: case-insensitive UTC" {
  debug_inspect(
    @timespec.parse_tz_offset("utc"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Utc"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: GMT+offset" {
  debug_inspect(
    @timespec.parse_tz_offset("GMT+9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT+0900"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT+09:00"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT-5"),
    content=(
      #|Hour(-5)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("UTC+5:30"),
    content=(
      #|Min(330)
    ),
  )
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
  debug_inspect(
    @timespec.parse_tz_offset("local"),
    content=(
      #|Local
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("LOCAL"),
    content=(
      #|Local
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Local"),
    content=(
      #|Local
    ),
  )
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
  debug_inspect(
    @timespec.parse_tz_offset("+14"),
    content=(
      #|Hour(14)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-12"),
    content=(
      #|Hour(-12)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+24"),
    content=(
      #|Hour(24)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-24"),
    content=(
      #|Hour(-24)
    ),
  )
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
