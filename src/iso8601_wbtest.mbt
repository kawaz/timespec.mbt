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

test "detect_tz_suffix: +HH (short)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00+09"), content="Some(Hour(9))")
}

test "detect_tz_suffix: -HH (short)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00-05"), content="Some(Hour(-5))")
}

test "detect_tz_suffix: +H (single digit)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00+9"), content="Some(Hour(9))")
}

test "detect_tz_suffix: -H (single digit)" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00-5"), content="Some(Hour(-5))")
}

test "detect_tz_suffix: +0 normalizes to Utc" {
  inspect(detect_tz_suffix("2024-01-01T12:00:00+0"), content="Some(Utc)")
}

test "detect_tz_suffix: date-like suffix not mistaken for TZ" {
  // フル日付の末尾の -DD は TZ ではない（コロンがないので時刻成分と判定しない）
  inspect(detect_tz_suffix("2024-01-15"), content="None")
  inspect(detect_tz_suffix("2024-01-01"), content="None")
  inspect(detect_tz_suffix("2024-12-31"), content="None")
}

test "detect_tz_suffix: date-only with no time never detects short TZ" {
  // 日付のみ（時刻なし）では +/-HH が検出されないことを確認
  inspect(detect_tz_suffix("20240115"), content="None")
}

test "detect_tz_suffix: not supported patterns return None" {
  // 文字列ベースの TZ 名は検出しない
  inspect(detect_tz_suffix("2024-01-01T12:00:00 JST"), content="None")
  inspect(detect_tz_suffix("2024-01-01T12:00:00 UTC"), content="None")
  // 空やTZのみの文字列
  inspect(detect_tz_suffix("Z"), content="Some(Utc)")
  inspect(detect_tz_suffix("+09:00"), content="Some(Hour(9))")
  // +H without preceding time (no colon) → None
  inspect(detect_tz_suffix("+9"), content="None")
}
