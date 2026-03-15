///|
test "parse_duration: basic units" {
  inspect(@src.parse_duration("5m"), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("1h30m"), content=(
    #|Ms(5400000)
  ))
  inspect(@src.parse_duration("300s"), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("1h30m45s"), content=(
    #|Ms(5445000)
  ))
  inspect(@src.parse_duration("2w"), content=(
    #|Ms(1209600000)
  ))
  inspect(@src.parse_duration("3d"), content=(
    #|Ms(259200000)
  ))
}

///|
test "parse_duration: decimal" {
  inspect(@src.parse_duration("1.5h"), content=(
    #|Ms(5400000)
  ))
  inspect(@src.parse_duration("3.5s"), content=(
    #|Ms(3500)
  ))
  inspect(@src.parse_duration("0.5m"), content=(
    #|Ms(30000)
  ))
}

///|
test "parse_duration: underscore" {
  inspect(@src.parse_duration("3_600_000ms"), content=(
    #|Ms(3600000)
  ))
  inspect(@src.parse_duration("1_000s"), content=(
    #|Ms(1000000)
  ))
  inspect(@src.parse_duration("1_000.5s"), content=(
    #|Ms(1000500)
  ))
  inspect(@src.parse_duration("1_000.5_0s"), content=(
    #|Ms(1000500)
  ))
}

///|
test "parse_duration: sub-ms units" {
  inspect(@src.parse_duration("100ms"), content=(
    #|Ms(100)
  ))
  inspect(@src.parse_duration("500us"), content=(
    #|MsNs(0, 500000)
  ))
  inspect(@src.parse_duration("1000ns"), content=(
    #|MsNs(0, 1000)
  ))
  inspect(@src.parse_duration("1ms500us"), content=(
    #|MsNs(1, 500000)
  ))
  inspect(@src.parse_duration("1.2ms900us"), content=(
    #|MsNs(2, 100000)
  ))
}

///|
test "parse_duration: duplicate merge" {
  inspect(@src.parse_duration("1h5m1h"), content=(
    #|Ms(7500000)
  ))
}

///|
test "parse_duration: sign with default_sign=Plus" {
  inspect(@src.parse_duration("5m"), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("+5m"), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("-5m"), content=(
    #|Ms(-300000)
  ))
}

///|
test "parse_duration: sign with default_sign=Minus" {
  inspect(@src.parse_duration("5m", default_sign=Minus), content=(
    #|Ms(-300000)
  ))
  inspect(@src.parse_duration("+5m", default_sign=Minus), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("-5m", default_sign=Minus), content=(
    #|Ms(-300000)
  ))
}

///|
test "parse_duration: sign with default_sign=Reject" {
  // 符号なしはエラー
  let result = try? @src.parse_duration("5m", default_sign=Reject)
  inspect(result, content=(
    #|Err(missing sign in duration: 5m)
  ))
  // 符号ありはOK
  inspect(@src.parse_duration("+5m", default_sign=Reject), content=(
    #|Ms(300000)
  ))
  inspect(@src.parse_duration("-5m", default_sign=Reject), content=(
    #|Ms(-300000)
  ))
}

///|
test "parse_duration: expression with signs" {
  inspect(@src.parse_duration("5s-2m+1h"), content=(
    #|Ms(3485000)
  ))
}

///|
test "parse_duration: whitespace" {
  inspect(@src.parse_duration("1h 2m"), content=(
    #|Ms(3720000)
  ))
  inspect(@src.parse_duration(" 1h 2m "), content=(
    #|Ms(3720000)
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
