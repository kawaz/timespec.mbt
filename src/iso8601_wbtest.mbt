///|
test "detect_tz_suffix: trailing Z" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00Z"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: trailing z (lowercase)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00z"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: +HH:MM" {
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00+09:00"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: -HH:MM" {
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-05:30"),
    content="Some(Min(-330))",
  )
}

///|
test "detect_tz_suffix: +HHMM" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00+0900"), content="Some(Hour(9))")
}

///|
test "detect_tz_suffix: -HHMM" {
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-0530"),
    content="Some(Min(-330))",
  )
}

///|
test "detect_tz_suffix: +00:00 normalizes to Utc" {
  debug_inspect(detect_tz_suffix("2024-01-01T00:00:00+00:00"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: no TZ (date only)" {
  debug_inspect(detect_tz_suffix("2024-01-01"), content="None")
}

///|
test "detect_tz_suffix: no TZ (datetime without TZ)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00"), content="None")
}

///|
test "detect_tz_suffix: no TZ (locale format)" {
  debug_inspect(detect_tz_suffix("11月12日 15:00"), content="None")
}

///|
test "detect_tz_suffix: empty string" {
  debug_inspect(detect_tz_suffix(""), content="None")
}

///|
test "detect_tz_suffix: with milliseconds and Z" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00.500Z"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: with milliseconds and +HH:MM" {
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00.500+09:00"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: +HH (short)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00+09"), content="Some(Hour(9))")
}

///|
test "detect_tz_suffix: -HH (short)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00-05"), content="Some(Hour(-5))")
}

///|
test "detect_tz_suffix: +H (single digit)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00+9"), content="Some(Hour(9))")
}

///|
test "detect_tz_suffix: -H (single digit)" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00-5"), content="Some(Hour(-5))")
}

///|
test "detect_tz_suffix: +0 normalizes to Utc" {
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00+0"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: date-like suffix not mistaken for TZ" {
  // フル日付の末尾の -DD は TZ ではない（コロンがないので時刻成分と判定しない）
  debug_inspect(detect_tz_suffix("2024-01-15"), content="None")
  debug_inspect(detect_tz_suffix("2024-01-01"), content="None")
  debug_inspect(detect_tz_suffix("2024-12-31"), content="None")
}

///|
test "detect_tz_suffix: date-only with no time never detects short TZ" {
  // 日付のみ（時刻なし）では +/-HH が検出されないことを確認
  debug_inspect(detect_tz_suffix("20240115"), content="None")
}

///|
test "saturating_add: normal addition" {
  debug_inspect(saturating_add(1L, 2L), content="3")
  debug_inspect(saturating_add(-1L, -2L), content="-3")
  debug_inspect(saturating_add(100L, -50L), content="50")
  debug_inspect(saturating_add(0L, 0L), content="0")
}

///|
test "saturating_add: positive overflow clamps to MAX_VALUE" {
  // MAX_VALUE + 1 would overflow; should clamp
  debug_inspect(saturating_add(@int64.MAX_VALUE, 1L), content="9223372036854775807")
  // MAX_VALUE + large positive should also clamp
  debug_inspect(
    saturating_add(@int64.MAX_VALUE, 3600000L),
    content="9223372036854775807",
  )
  // Near MAX_VALUE: (MAX_VALUE - 1000) + 3600000 overflows
  debug_inspect(
    saturating_add(@int64.MAX_VALUE - 1000L, 3600000L),
    content="9223372036854775807",
  )
}

///|
test "saturating_add: negative overflow clamps to MIN_VALUE" {
  // MIN_VALUE - 1 would overflow; should clamp
  debug_inspect(
    saturating_add(@int64.MIN_VALUE, -1L),
    content="-9223372036854775808",
  )
  // MIN_VALUE + large negative should also clamp
  debug_inspect(
    saturating_add(@int64.MIN_VALUE, -3600000L),
    content="-9223372036854775808",
  )
}

///|
test "saturating_add: boundary no-overflow" {
  // MAX_VALUE + 0 = MAX_VALUE (no overflow)
  debug_inspect(
    saturating_add(@int64.MAX_VALUE, 0L),
    content="9223372036854775807",
  )
  // MIN_VALUE + 0 = MIN_VALUE (no overflow)
  debug_inspect(
    saturating_add(@int64.MIN_VALUE, 0L),
    content="-9223372036854775808",
  )
  // MAX_VALUE - 1 = MAX_VALUE + (-1), no overflow
  debug_inspect(
    saturating_add(@int64.MAX_VALUE, -1L),
    content="9223372036854775806",
  )
  // MIN_VALUE + 1, no overflow
  debug_inspect(
    saturating_add(@int64.MIN_VALUE, 1L),
    content="-9223372036854775807",
  )
}

///|
test "detect_tz_suffix: not supported patterns return None" {
  // 文字列ベースの TZ 名は検出しない
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00 JST"), content="None")
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00 UTC"), content="None")
  // 空やTZのみの文字列
  debug_inspect(detect_tz_suffix("Z"), content="Some(Utc)")
  debug_inspect(detect_tz_suffix("+09:00"), content="Some(Hour(9))")
  // +H without preceding time (no colon) → None
  debug_inspect(detect_tz_suffix("+9"), content="None")
}
