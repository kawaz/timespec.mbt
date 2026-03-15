///|
test "to_cli_string: Absolute" {
  let ts : @src.TimeSpec = Absolute(@src.EpochTime(1704067200000L), @src.Duration(0L)) // 2024-01-01T00:00:00Z
  inspect(ts.to_cli_string(), content=(
    #|2024-01-01T00:00:00Z
  ))
}

///|
test "to_cli_string: Relative positive" {
  let ts : @src.TimeSpec = Relative(@src.EpochTime(1_300_000L), @src.Duration(300_000L))
  inspect(ts.to_cli_string(), content=(
    #|+5m
  ))
}

///|
test "to_cli_string: Relative negative" {
  let ts : @src.TimeSpec = Relative(@src.EpochTime(700_000L), @src.Duration(-300_000L))
  inspect(ts.to_cli_string(), content=(
    #|-5m
  ))
}

///|
test "to_cli_string: Relative zero" {
  let ts : @src.TimeSpec = Relative(@src.EpochTime(1_000_000L), @src.Duration(0L))
  inspect(ts.to_cli_string(), content=(
    #|+0s
  ))
}

///|
test "to_cli_string: Relative large" {
  // 1h30m = 5_400_000ms
  let ts : @src.TimeSpec = Relative(@src.EpochTime(0L), @src.Duration(5_400_000L))
  inspect(ts.to_cli_string(), content=(
    #|+1h30m
  ))
}

///|
test "format_duration: weeks and days" {
  // 1w2d = 604800000 + 172800000 = 777600000 ms
  let ts : @src.TimeSpec = Relative(@src.EpochTime(0L), @src.Duration(777_600_000L))
  inspect(ts.to_cli_string(), content=(
    #|+1w2d
  ))
}

///|
test "format_duration: all units" {
  // 1h30m45s500ms
  let ts : @src.TimeSpec = Relative(@src.EpochTime(0L), @src.Duration(5_445_500L))
  inspect(ts.to_cli_string(), content=(
    #|+1h30m45s500ms
  ))
}

///|
test "format_duration: ms only" {
  let ts : @src.TimeSpec = Relative(@src.EpochTime(0L), @src.Duration(500L))
  inspect(ts.to_cli_string(), content=(
    #|+500ms
  ))
}

///|
test "to_cli_string: Absolute with milliseconds" {
  let ts : @src.TimeSpec = Absolute(@src.EpochTime(1704067200500L), @src.Duration(0L)) // .500
  inspect(ts.to_cli_string(), content=(
    #|2024-01-01T00:00:00.500Z
  ))
}

///|
test "to_cli_string: with custom epoch" {
  // EpochTime ms=0 with Snowflake epoch → Unix ms = 0 + 1288834974657 → ISO 8601
  let ts : @src.TimeSpec = Absolute(@src.EpochTime(0L), @src.Duration(0L))
  let snowflake_epoch = @src.EpochTime(1288834974657L)
  inspect(ts.to_cli_string(epoch=snowflake_epoch), content=(
    #|2010-11-04T01:42:54.657Z
  ))
}
