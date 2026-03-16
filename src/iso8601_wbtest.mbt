test "detect_tz_suffix: trailing Z" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00Z"), content="Some(Utc)")
}

test "detect_tz_suffix: trailing z (lowercase)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00z"), content="Some(Utc)")
}

test "detect_tz_suffix: +HH:MM" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00+09:00"), content="Some(Hour(9))")
}

test "detect_tz_suffix: -HH:MM" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00-05:30"), content="Some(Min(-330))")
}

test "detect_tz_suffix: +HHMM" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00+0900"), content="Some(Hour(9))")
}

test "detect_tz_suffix: -HHMM" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00-0530"), content="Some(Min(-330))")
}

test "detect_tz_suffix: +00:00 normalizes to Utc" {
  inspect(detect_tz_suffix("2024-01-01T00:00:00+00:00"), content="Some(Utc)")
}

test "detect_tz_suffix: no TZ (date only)" {
  inspect(detect_tz_suffix("2024-01-01"), content="None")
}

test "detect_tz_suffix: no TZ (datetime without TZ)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00"), content="None")
}

test "detect_tz_suffix: no TZ (locale format)" {
  inspect(detect_tz_suffix("11月12日 15:00"), content="None")
}

test "detect_tz_suffix: empty string" {
  inspect(detect_tz_suffix(""), content="None")
}

test "detect_tz_suffix: with milliseconds and Z" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00.500Z"), content="Some(Utc)")
}

test "detect_tz_suffix: with milliseconds and +HH:MM" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00.500+09:00"), content="Some(Hour(9))")
}

test "detect_tz_suffix: date-like suffix not mistaken for TZ (2024-01-15)" {
  // -15 should NOT be detected as TZ offset
  inspect(detect_tz_suffix("2024-01-15"), content="None")
}
