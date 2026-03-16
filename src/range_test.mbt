///|
fn range_test_now() -> UInt64 {
  1_000_000UL // 1,000,000 ms = 1000 seconds
}

///|
test "parse_range: since single value" {
  let r = @src.parse_range(since="5m", now=range_test_now, default_sign=Minus)
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|None
  ))
}

///|
test "parse_range: until single value" {
  let r = @src.parse_range(until="5m", now=range_test_now, default_sign=Minus)
  inspect(r.since, content=(
    #|None
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
}

///|
test "parse_range: both relative independent" {
  // Both Relative → 独立解決（各自 now 基準）
  let r = @src.parse_range(
    since="5m", until="3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: mixed - until absolute anchor" {
  // 5m~@3m: Mixed → @ 側 (until) が anchor
  // until = A(now-3m), since = R(until-5m)
  let r = @src.parse_range(
    since="5m", until="@3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(520000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: both absolute independent" {
  // @5m~@3m: 両方 Absolute → 独立解決
  let r = @src.parse_range(
    since="@5m", until="@3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: @ with explicit sign" {
  // @5m~@+3m
  let r = @src.parse_range(
    since="@5m", until="@+3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(EpochTime(1180000), Duration(180000)))
  ))
}

///|
test "parse_range: swap" {
  // swap=true: since > until なら入れ替え
  let r = @src.parse_range(
    since="3m", until="5m", now=range_test_now, default_sign=Minus, swap=true,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: empty since" {
  // since is empty, only until
  let r = @src.parse_range(
    until="3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|None
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: explicit positive sign on until" {
  let r = @src.parse_range(
    since="5m", until="+3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(1180000), Duration(180000)))
  ))
}

///|
test "parse_range: explicit negative sign on until" {
  let r = @src.parse_range(
    since="5m", until="-3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: mixed - since absolute anchor" {
  // @5m~3m: since=A(now-5m), until=R(since-3m)
  let r = @src.parse_range(
    since="@5m", until="3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(520000), Duration(-180000)))
  ))
}

///|
test "parse_range: mixed - until absolute, since relative" {
  // Range + Mixed → absolute 側が anchor
  let r = @src.parse_range(
    since="5m", until="@3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Relative(EpochTime(520000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Absolute(EpochTime(820000), Duration(-180000)))
  ))
}

///|
test "parse_range: mixed - since absolute, until relative (until context equivalent)" {
  let r = @src.parse_range(
    since="@5m", until="3m", now=range_test_now, default_sign=Minus,
  )
  inspect(r.since, content=(
    #|Some(Absolute(EpochTime(700000), Duration(-300000)))
  ))
  inspect(r.until, content=(
    #|Some(Relative(EpochTime(520000), Duration(-180000)))
  ))
}

///|
test "parse_range: both empty returns empty range" {
  let r = @src.parse_range(now=range_test_now, default_sign=Minus)
  inspect(r.since, content=(
    #|None
  ))
  inspect(r.until, content=(
    #|None
  ))
}

///|
test "parse_range: invalid input raises error" {
  let r = try? @src.parse_range(
    since="invalid_xyz", now=range_test_now, default_sign=Minus,
  )
  assert_true(r is Err(_))
}

///|
test "parse_range: input~ with tilde" {
  let a = @src.parse_range(since="5m", until="3m", now=range_test_now, default_sign=Minus)
  let b = @src.parse_range(input="5m~3m", now=range_test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_range: input~ since only (5d~)" {
  let a = @src.parse_range(since="5d", now=range_test_now, default_sign=Minus)
  let b = @src.parse_range(input="5d~", now=range_test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_range: input~ until only (~3m)" {
  let a = @src.parse_range(until="3m", now=range_test_now, default_sign=Minus)
  let b = @src.parse_range(input="~3m", now=range_test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_range: input~ no tilde (since only)" {
  let a = @src.parse_range(since="5m", now=range_test_now, default_sign=Minus)
  let b = @src.parse_range(input="5m", now=range_test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_range: explicit since~/until~ overrides input~" {
  let r = @src.parse_range(
    input="99d~99d", since="5m", until="3m",
    now=range_test_now, default_sign=Minus,
  )
  let expected = @src.parse_range(since="5m", until="3m", now=range_test_now, default_sign=Minus)
  assert_true(r == expected)
}

///|
test "parse_range: no arguments" {
  let r = @src.parse_range()
  inspect(r, content=(
    #|{since: None, until: None}
  ))
}
