///|
test "to_cli_string: Absolute" {
  let ts : @src.TimeSpec = Absolute(1704067200000L) // 2024-01-01T00:00:00Z
  inspect(ts.to_cli_string(), content=(
    #|2024-01-01T00:00:00Z
  ))
}

///|
test "to_cli_string: Relative positive" {
  let ts : @src.TimeSpec = Relative(1_300_000L, Ms(300_000L))
  inspect(ts.to_cli_string(), content=(
    #|+5m
  ))
}

///|
test "to_cli_string: Relative negative" {
  let ts : @src.TimeSpec = Relative(700_000L, Ms(-300_000L))
  inspect(ts.to_cli_string(), content=(
    #|-5m
  ))
}

///|
test "to_cli_string: Relative zero" {
  let ts : @src.TimeSpec = Relative(1_000_000L, Ms(0L))
  inspect(ts.to_cli_string(), content=(
    #|+0s
  ))
}

///|
test "to_cli_string: Relative large" {
  // 1h30m = 5_400_000ms
  let ts : @src.TimeSpec = Relative(0L, Ms(5_400_000L))
  inspect(ts.to_cli_string(), content=(
    #|+1h30m
  ))
}

///|
test "to_cli_string: Relative with sub-ms" {
  let ts : @src.TimeSpec = Relative(0L, MsNs(1L, 500_000))
  inspect(ts.to_cli_string(), content=(
    #|+1ms500us
  ))
}

///|
test "format_duration: weeks and days" {
  // 1w2d = 604800000 + 172800000 = 777600000 ms
  let ts : @src.TimeSpec = Relative(0L, Ms(777_600_000L))
  inspect(ts.to_cli_string(), content=(
    #|+1w2d
  ))
}

///|
test "format_duration: all units" {
  // 1h30m45s500ms
  let ts : @src.TimeSpec = Relative(0L, Ms(5_445_500L))
  inspect(ts.to_cli_string(), content=(
    #|+1h30m45s500ms
  ))
}

///|
test "format_duration: ms only" {
  let ts : @src.TimeSpec = Relative(0L, Ms(500L))
  inspect(ts.to_cli_string(), content=(
    #|+500ms
  ))
}

///|
test "format_duration: us only" {
  let ts : @src.TimeSpec = Relative(0L, MsNs(0L, 500_000))
  inspect(ts.to_cli_string(), content=(
    #|+500us
  ))
}

///|
test "format_duration: ns only" {
  let ts : @src.TimeSpec = Relative(0L, MsNs(0L, 500))
  inspect(ts.to_cli_string(), content=(
    #|+500ns
  ))
}

///|
test "to_cli_string: Absolute with milliseconds" {
  let ts : @src.TimeSpec = Absolute(1704067200500L) // .500
  inspect(ts.to_cli_string(), content=(
    #|2024-01-01T00:00:00.500Z
  ))
}
