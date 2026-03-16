///|
test "parse_duration: basic units" {
  inspect(@src.parse_duration("5m"), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("1h30m"), content=(
    #|Duration(5400000)
  ))
  inspect(@src.parse_duration("300s"), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("1h30m45s"), content=(
    #|Duration(5445000)
  ))
  inspect(@src.parse_duration("2w"), content=(
    #|Duration(1209600000)
  ))
  inspect(@src.parse_duration("3d"), content=(
    #|Duration(259200000)
  ))
}

///|
test "parse_duration: decimal" {
  inspect(@src.parse_duration("1.5h"), content=(
    #|Duration(5400000)
  ))
  inspect(@src.parse_duration("3.5s"), content=(
    #|Duration(3500)
  ))
  inspect(@src.parse_duration("0.5m"), content=(
    #|Duration(30000)
  ))
}

///|
test "parse_duration: underscore" {
  inspect(@src.parse_duration("3_600_000ms"), content=(
    #|Duration(3600000)
  ))
  inspect(@src.parse_duration("1_000s"), content=(
    #|Duration(1000000)
  ))
  inspect(@src.parse_duration("1_000.5s"), content=(
    #|Duration(1000500)
  ))
  inspect(@src.parse_duration("1_000.5_0s"), content=(
    #|Duration(1000500)
  ))
}

///|
test "parse_duration: ms unit" {
  inspect(@src.parse_duration("100ms"), content=(
    #|Duration(100)
  ))
}

///|
test "parse_duration: sub-ms units are errors" {
  let r1 = try? @src.parse_duration("500us")
  assert_true(r1 is Err(_))
  let r2 = try? @src.parse_duration("1000ns")
  assert_true(r2 is Err(_))
  let r3 = try? @src.parse_duration("500\u03BCs")
  assert_true(r3 is Err(_))
}

///|
test "parse_duration: duplicate merge" {
  inspect(@src.parse_duration("1h5m1h"), content=(
    #|Duration(7500000)
  ))
}

///|
test "parse_duration: sign with default_sign=Plus" {
  inspect(@src.parse_duration("5m"), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("+5m"), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("-5m"), content=(
    #|Duration(-300000)
  ))
}

///|
test "parse_duration: sign with default_sign=Minus" {
  inspect(@src.parse_duration("5m", default_sign=Minus), content=(
    #|Duration(-300000)
  ))
  inspect(@src.parse_duration("+5m", default_sign=Minus), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("-5m", default_sign=Minus), content=(
    #|Duration(-300000)
  ))
}

///|
test "parse_duration: sign with default_sign=Reject" {
  // 符号なしはエラー
  let result = try? @src.parse_duration("5m", default_sign=Reject)
  inspect(result, content=(
    #|Err(ParseError("missing sign in duration: 5m"))

  ))
  // 符号ありはOK
  inspect(@src.parse_duration("+5m", default_sign=Reject), content=(
    #|Duration(300000)
  ))
  inspect(@src.parse_duration("-5m", default_sign=Reject), content=(
    #|Duration(-300000)
  ))
}

///|
test "parse_duration: expression with signs" {
  inspect(@src.parse_duration("5s-2m+1h"), content=(
    #|Duration(3485000)
  ))
}

///|
test "parse_duration: whitespace" {
  inspect(@src.parse_duration("1h 2m"), content=(
    #|Duration(3720000)
  ))
  inspect(@src.parse_duration(" 1h 2m "), content=(
    #|Duration(3720000)
  ))
  inspect(@src.parse_duration(" 1 h 2 m "), content=(
    #|Duration(3720000)
  ))
}

///|
test "parse_duration: errors" {
  // 空文字
  let r1 = try? @src.parse_duration("")
  assert_true(r1 is Err(_))
  // 年は非対応
  let r2 = try? @src.parse_duration("5y")
  assert_true(r2 is Err(_))
  // 数字のみ（ユニットなし）
  let r3 = try? @src.parse_duration("5")
  assert_true(r3 is Err(_))
}

///|
test "Duration constants" {
  inspect(@src.millisecond, content=(
    #|Duration(1)
  ))
  inspect(@src.second, content=(
    #|Duration(1000)
  ))
  inspect(@src.minute, content=(
    #|Duration(60000)
  ))
  inspect(@src.hour, content=(
    #|Duration(3600000)
  ))
  inspect(@src.day, content=(
    #|Duration(86400000)
  ))
  inspect(@src.week, content=(
    #|Duration(604800000)
  ))
}

///|
test "Duration addition" {
  let d = @src.hour + @src.minute.scale(30L) + @src.second.scale(45L)
  inspect(d, content=(
    #|Duration(5445000)
  ))
}

///|
test "Duration subtraction" {
  let d = @src.hour - @src.minute.scale(30L)
  inspect(d, content=(
    #|Duration(1800000)
  ))
}

///|
test "Duration negation" {
  inspect(-@src.hour, content=(
    #|Duration(-3600000)
  ))
}

///|
test "Duration scale" {
  inspect(@src.second.scale(90L), content=(
    #|Duration(90000)
  ))
  inspect(@src.hour.scale(24L), content=(
    #|Duration(86400000)
  ))
}

///|
test "EpochTime + Duration" {
  let t = @src.EpochTime(1_000_000L)
  let d = @src.minute.scale(5L)
  inspect(t.add_duration(d), content=(
    #|EpochTime(1300000)
  ))
}

///|
test "parse_duration: long unit names" {
  inspect(@src.parse_duration("3minutes"), content=(
    #|Duration(180000)
  ))
  inspect(@src.parse_duration("1hour"), content=(
    #|Duration(3600000)
  ))
  inspect(@src.parse_duration("2days"), content=(
    #|Duration(172800000)
  ))
  inspect(@src.parse_duration("1week"), content=(
    #|Duration(604800000)
  ))
  inspect(@src.parse_duration("500milliseconds"), content=(
    #|Duration(500)
  ))
  inspect(@src.parse_duration("30sec"), content=(
    #|Duration(30000)
  ))
  inspect(@src.parse_duration("5min"), content=(
    #|Duration(300000)
  ))
}

///|
test "parse_duration: ago" {
  inspect(@src.parse_duration("3 minutes ago"), content=(
    #|Duration(-180000)
  ))
  inspect(@src.parse_duration("1 hour 30 minutes ago"), content=(
    #|Duration(-5400000)
  ))
  inspect(@src.parse_duration("5s ago"), content=(
    #|Duration(-5000)
  ))
}

///|
test "parse_duration: ago negates group" {
  // グループ[1h+30m]を反転 → -90m = -5400000ms
  inspect(@src.parse_duration("1 hour 30 minutes ago"), content=(
    #|Duration(-5400000)
  ))
}

///|
test "parse_duration: ago with explicit plus" {
  // グループ[1h] + グループ[30m]を反転 → 1h + (-30m) = 30m = 1800000ms
  inspect(@src.parse_duration("1 hour + 30 minutes ago"), content=(
    #|Duration(1800000)
  ))
}

///|
test "parse_duration: ago with explicit minus" {
  // グループ[1h] - グループ[30m]を反転 → 1h - (-30m) = 90m = 5400000ms
  inspect(@src.parse_duration("1 hour - 30 minutes ago"), content=(
    #|Duration(5400000)
  ))
}

///|
test "parse_duration: ago then more segments" {
  // グループ[30m]を反転, 新グループ[1h] → -30m + 1h = 30m
  inspect(@src.parse_duration("30 minutes ago 1h"), content=(
    #|Duration(1800000)
  ))
  // グループ[30m]を反転, + グループ[1h] → -30m + 1h = 30m
  inspect(@src.parse_duration("30 minutes ago + 1h"), content=(
    #|Duration(1800000)
  ))
  // グループ[30m]を反転, - グループ[1h] → -30m - 1h = -90m
  inspect(@src.parse_duration("30 minutes ago - 1h"), content=(
    #|Duration(-5400000)
  ))
}

///|
test "parse_duration: ago with leading sign" {
  // -5m ago: 先頭 - で negate=true, グループ[5m], ago反転 → group=-5m,
  // total=1*(-5m)=-5m, negate → +5m = 300000ms
  inspect(@src.parse_duration("-5m ago"), content=(
    #|Duration(300000)
  ))
}

///|
test "parse_duration: mixed long and short units" {
  inspect(@src.parse_duration("1hour 30m"), content=(
    #|Duration(5400000)
  ))
  inspect(@src.parse_duration("2 days 5h"), content=(
    #|Duration(190800000)
  ))
}
