///|
fn range_test_now() -> UInt64 {
  1_000_000UL // 1,000,000 ms = 1000 seconds
}

///|
test "parse_range: since single value" {
  let r = @src.parse_range("5m", context=Since, now=range_test_now, default_sign=Minus)
  inspect(r.since, content=(
    #|Some(Relative(700000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|None
  ))
}

///|
test "parse_range: until single value" {
  let r = @src.parse_range("5m", context=Until, now=range_test_now, default_sign=Minus)
  inspect(r.since, content=(
    #|None
  ))
  inspect(r.until, content=(
    #|Some(Relative(700000, Ms(-300000)))
  ))
}

///|
test "parse_range: since with tilde" {
  // 5m~3m: since=R(now-5m), until=R(since+3m=now-2m)
  let r = @src.parse_range(
    "5m~3m", context=Since, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(700000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(880000, Ms(-180000)))
  ))
}

///|
test "parse_range: since with @ on until (Mixed)" {
  // 5m~@3m: Mixed → @ 側 (until) が anchor
  // until = A(now-3m), since = R(until-5m)
  let r = @src.parse_range(
    "5m~@3m", context=Since, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(520000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(820000))
  ))
}

///|
test "parse_range: both absolute" {
  // @5m~@3m: 両方 Absolute → 独立解決
  let r = @src.parse_range(
    "@5m~@3m", context=Since, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(700000))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(820000))
  ))
}

///|
test "parse_range: @ with explicit sign" {
  // @5m~@+3m
  let r = @src.parse_range(
    "@5m~@+3m", context=Since, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(700000))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(1180000))
  ))
}

///|
test "parse_range: range context independent" {
  // Range: 各パート独立
  let r = @src.parse_range(
    "5m~3m", context=Range, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(700000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(820000, Ms(-180000)))
  ))
}

///|
test "parse_range: swap" {
  // swap=true: since > until なら入れ替え
  let r = @src.parse_range(
    "3m~5m", context=Range, now=range_test_now, default_sign=Minus, swap=true,
  )
  // Range context で independent: since=now-3m=700000, until=now-5m=700000
  // 3m < 5m なので since > until → swap
  inspect(r.since, content=(
    #|Some(Relative(700000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(820000, Ms(-180000)))
  ))
}

///|
test "parse_range: until context with tilde" {
  let r = @src.parse_range(
    "5m~3m", context=Until, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(520000, Ms(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(820000, Ms(-180000)))
  ))
}

///|
test "parse_range: empty since part" {
  // ~3m: since is empty
  let r = @src.parse_range(
    "~3m", context=Since, now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|None
  ))
  inspect(r.until, content=(
    #|Some(Relative(820000, Ms(-180000)))
  ))
}
