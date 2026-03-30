///|
test "to_cli_string: Absolute" {
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(1704067200000L),
    @timespec.Duration(0L),
  ) // 2024-01-01T00:00:00Z
  inspect(
    ts.to_cli_string(),
    content=(
      #|2024-01-01T00:00:00Z
    ),
  )
}

///|
test "to_cli_string: Relative positive" {
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(1_300_000L),
    @timespec.Duration(300_000L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+5m
    ),
  )
}

///|
test "to_cli_string: Relative negative" {
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(700_000L),
    @timespec.Duration(-300_000L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|-5m
    ),
  )
}

///|
test "to_cli_string: Relative zero" {
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(1_000_000L),
    @timespec.Duration(0L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+0s
    ),
  )
}

///|
test "to_cli_string: Relative large" {
  // 1h30m = 5_400_000ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(5_400_000L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+1h30m
    ),
  )
}

///|
test "format_duration: weeks and days" {
  // 1w2d = 604800000 + 172800000 = 777600000 ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(777_600_000L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+1w2d
    ),
  )
}

///|
test "format_duration: all units" {
  // 1h30m45s500ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(5_445_500L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+1h30m45s500ms
    ),
  )
}

///|
test "format_duration: ms only" {
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(500L),
  )
  inspect(
    ts.to_cli_string(),
    content=(
      #|+500ms
    ),
  )
}

///|
test "to_cli_string: Absolute with milliseconds" {
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(1704067200500L),
    @timespec.Duration(0L),
  ) // .500
  inspect(
    ts.to_cli_string(),
    content=(
      #|2024-01-01T00:00:00.500Z
    ),
  )
}

///|
test "format_duration: Int64.min_value does not overflow" {
  // Int64.min_value = -9223372036854775808
  // -Int64.min_value overflows back to min_value in two's complement.
  // format_duration should handle this edge case correctly.
  let min_val = @int64.MIN_VALUE
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(min_val),
  )
  let result = ts.to_cli_string()
  // Should start with "-" (negative duration)
  inspect(result[:1].to_string(), content="-")
  // Should NOT start with "+-" or be "+0s" (which would indicate overflow)
  assert_true(result != "+0s")
  assert_true(result != "+-0s")
  // The magnitude should be 9223372036854775808ms decomposed into units.
  // 9223372036854775808 ms = 15250284452w3d7h12m55s808ms
  // But since remain is set to Int64.max_value (off by 1ms), we add that 1ms back.
  // Let's just verify it parses to a reasonable negative duration string.
  inspect(
    result,
    content="-15250284452w3d7h12m55s808ms",
  )
}

///|
test "to_cli_string: with custom epoch" {
  // EpochTime ms=0 with Snowflake epoch → Unix ms = 0 + 1288834974657 → ISO 8601
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(0L),
    @timespec.Duration(0L),
  )
  let snowflake_epoch = @timespec.EpochTime(1288834974657L)
  inspect(
    ts.to_cli_string(epoch=snowflake_epoch),
    content=(
      #|2010-11-04T01:42:54.657Z
    ),
  )
}
