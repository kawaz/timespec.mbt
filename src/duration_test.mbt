///|
test "parse_duration: basic units" {
  debug_inspect(
    @timespec.parse_duration("5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1h30m"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("300s"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1h30m45s"),
    content=(
      #|Duration(5445000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2w"),
    content=(
      #|Duration(1209600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("3d"),
    content=(
      #|Duration(259200000)
    ),
  )
}

///|
test "parse_duration: decimal" {
  debug_inspect(
    @timespec.parse_duration("1.5h"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("3.5s"),
    content=(
      #|Duration(3500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("0.5m"),
    content=(
      #|Duration(30000)
    ),
  )
}

///|
test "parse_duration: underscore" {
  debug_inspect(
    @timespec.parse_duration("3_600_000ms"),
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000s"),
    content=(
      #|Duration(1000000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000.5s"),
    content=(
      #|Duration(1000500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000.5_0s"),
    content=(
      #|Duration(1000500)
    ),
  )
}

///|
test "parse_duration: ms unit" {
  debug_inspect(
    @timespec.parse_duration("100ms"),
    content=(
      #|Duration(100)
    ),
  )
}

///|
test "parse_duration: sub-ms units are errors" {
  let r1 = try? @timespec.parse_duration("500us")
  assert_true(r1 is Err(_))
  let r2 = try? @timespec.parse_duration("1000ns")
  assert_true(r2 is Err(_))
  let r3 = try? @timespec.parse_duration("500\u03BCs")
  assert_true(r3 is Err(_))
}

///|
test "parse_duration: duplicate merge" {
  debug_inspect(
    @timespec.parse_duration("1h5m1h"),
    content=(
      #|Duration(7500000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Plus" {
  debug_inspect(
    @timespec.parse_duration("5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("+5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m"),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Minus" {
  debug_inspect(
    @timespec.parse_duration("5m", default_sign=Minus),
    content=(
      #|Duration(-300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("+5m", default_sign=Minus),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m", default_sign=Minus),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Reject" {
  // 符号なしはエラー
  let result = try? @timespec.parse_duration("5m", default_sign=Reject)
  debug_inspect(
    result,
    content=(
      #|Err(ParseError("missing sign in duration: 5m"))
    ),
  )
  // 符号ありはOK
  debug_inspect(
    @timespec.parse_duration("+5m", default_sign=Reject),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m", default_sign=Reject),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: expression with signs" {
  debug_inspect(
    @timespec.parse_duration("5s-2m+1h"),
    content=(
      #|Duration(3485000)
    ),
  )
}

///|
test "parse_duration: whitespace" {
  debug_inspect(
    @timespec.parse_duration("1h 2m"),
    content=(
      #|Duration(3720000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration(" 1h 2m "),
    content=(
      #|Duration(3720000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration(" 1 h 2 m "),
    content=(
      #|Duration(3720000)
    ),
  )
}

///|
test "parse_duration: errors" {
  // 空文字
  let r1 = try? @timespec.parse_duration("")
  assert_true(r1 is Err(_))
  // 年は非対応
  let r2 = try? @timespec.parse_duration("5y")
  assert_true(r2 is Err(_))
  // 数字のみ（ユニットなし）
  let r3 = try? @timespec.parse_duration("5")
  assert_true(r3 is Err(_))
}

///|
test "Duration constants" {
  debug_inspect(
    @timespec.millisecond,
    content=(
      #|Duration(1)
    ),
  )
  debug_inspect(
    @timespec.second,
    content=(
      #|Duration(1000)
    ),
  )
  debug_inspect(
    @timespec.minute,
    content=(
      #|Duration(60000)
    ),
  )
  debug_inspect(
    @timespec.hour,
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.day,
    content=(
      #|Duration(86400000)
    ),
  )
  debug_inspect(
    @timespec.week,
    content=(
      #|Duration(604800000)
    ),
  )
}

///|
test "Duration addition" {
  let d = @timespec.hour +
    @timespec.minute.scale(30L) +
    @timespec.second.scale(45L)
  debug_inspect(
    d,
    content=(
      #|Duration(5445000)
    ),
  )
}

///|
test "Duration subtraction" {
  let d = @timespec.hour - @timespec.minute.scale(30L)
  debug_inspect(
    d,
    content=(
      #|Duration(1800000)
    ),
  )
}

///|
test "Duration negation" {
  debug_inspect(
    -@timespec.hour,
    content=(
      #|Duration(-3600000)
    ),
  )
}

///|
test "Duration scale" {
  debug_inspect(
    @timespec.second.scale(90L),
    content=(
      #|Duration(90000)
    ),
  )
  debug_inspect(
    @timespec.hour.scale(24L),
    content=(
      #|Duration(86400000)
    ),
  )
}

///|
test "EpochTime + Duration" {
  let t = @timespec.EpochTime(1_000_000L)
  let d = @timespec.minute.scale(5L)
  debug_inspect(
    t.add_duration(d),
    content=(
      #|EpochTime(1300000)
    ),
  )
}

///|
test "parse_duration: long unit names" {
  debug_inspect(
    @timespec.parse_duration("3minutes"),
    content=(
      #|Duration(180000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1hour"),
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2days"),
    content=(
      #|Duration(172800000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1week"),
    content=(
      #|Duration(604800000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("500milliseconds"),
    content=(
      #|Duration(500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("30sec"),
    content=(
      #|Duration(30000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("5min"),
    content=(
      #|Duration(300000)
    ),
  )
}

///|
test "parse_duration: ago" {
  debug_inspect(
    @timespec.parse_duration("3 minutes ago"),
    content=(
      #|Duration(-180000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1 hour 30 minutes ago"),
    content=(
      #|Duration(-5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("5s ago"),
    content=(
      #|Duration(-5000)
    ),
  )
}

///|
test "parse_duration: ago negates group" {
  // グループ[1h+30m]を反転 → -90m = -5400000ms
  debug_inspect(
    @timespec.parse_duration("1 hour 30 minutes ago"),
    content=(
      #|Duration(-5400000)
    ),
  )
}

///|
test "parse_duration: ago with explicit plus" {
  // グループ[1h] + グループ[30m]を反転 → 1h + (-30m) = 30m = 1800000ms
  debug_inspect(
    @timespec.parse_duration("1 hour + 30 minutes ago"),
    content=(
      #|Duration(1800000)
    ),
  )
}

///|
test "parse_duration: ago with explicit minus" {
  // グループ[1h] - グループ[30m]を反転 → 1h - (-30m) = 90m = 5400000ms
  debug_inspect(
    @timespec.parse_duration("1 hour - 30 minutes ago"),
    content=(
      #|Duration(5400000)
    ),
  )
}

///|
test "parse_duration: ago then more segments" {
  // グループ[30m]を反転, 新グループ[1h] → -30m + 1h = 30m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago 1h"),
    content=(
      #|Duration(1800000)
    ),
  )
  // グループ[30m]を反転, + グループ[1h] → -30m + 1h = 30m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago + 1h"),
    content=(
      #|Duration(1800000)
    ),
  )
  // グループ[30m]を反転, - グループ[1h] → -30m - 1h = -90m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago - 1h"),
    content=(
      #|Duration(-5400000)
    ),
  )
}

///|
test "parse_duration: ago with leading sign" {
  // -5m ago: 先頭 - で negate=true, グループ[5m], ago反転 → group=-5m,
  // total=1*(-5m)=-5m, negate → +5m = 300000ms
  debug_inspect(
    @timespec.parse_duration("-5m ago"),
    content=(
      #|Duration(300000)
    ),
  )
}

///|
test "parse_duration: mixed long and short units" {
  debug_inspect(
    @timespec.parse_duration("1hour 30m"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2 days 5h"),
    content=(
      #|Duration(190800000)
    ),
  )
}

///|
test "parse_duration: overflow detection" {
  // 非常に大きな数値で parse_number のオーバーフロー検出
  let r1 = try? @timespec.parse_duration("9999999999999999999ms")
  debug_inspect(
    r1,
    content="Err(ParseError(\"number too large\"))",
  )
  // checked_mul でオーバーフロー検出 (15250284453 * 604800000 > Int64.MAX)
  let r2 = try? @timespec.parse_duration("15250284453w")
  debug_inspect(
    r2,
    content="Err(ParseError(\"duration overflow\"))",
  )
  // checked_mul でオーバーフロー検出 (99999999999999h * 3600000 > Int64.MAX)
  let r3 = try? @timespec.parse_duration("99999999999999h")
  debug_inspect(
    r3,
    content="Err(ParseError(\"duration overflow\"))",
  )
}

///|
test "parse_duration: special inputs" {
  // 空文字列 → エラー
  let r1 = try? @timespec.parse_duration("")
  debug_inspect(
    r1,
    content="Err(ParseError(\"empty duration string\"))",
  )
  // 数値のみ（単位なし） → エラー
  let r2 = try? @timespec.parse_duration("123")
  debug_inspect(
    r2,
    content="Err(ParseError(\"missing unit after number in: 123\"))",
  )
  // 非常に小さい小数 → 1ms
  debug_inspect(
    @timespec.parse_duration("0.001s"),
    content="Duration(1)",
  )
  // ゼロ値
  debug_inspect(
    @timespec.parse_duration("0s"),
    content="Duration(0)",
  )
  debug_inspect(
    @timespec.parse_duration("0m"),
    content="Duration(0)",
  )
  debug_inspect(
    @timespec.parse_duration("0h"),
    content="Duration(0)",
  )
}
