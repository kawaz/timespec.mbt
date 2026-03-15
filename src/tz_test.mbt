///|
test "parse_tz_offset: empty and UTC variants" {
  inspect(@src.parse_tz_offset(""), content=(
    #|Utc
  ))
  inspect(@src.parse_tz_offset("Z"), content=(
    #|Utc
  ))
  inspect(@src.parse_tz_offset("UTC"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: hour only" {
  inspect(@src.parse_tz_offset("9"), content=(
    #|Hour(9)
  ))
  inspect(@src.parse_tz_offset("+9"), content=(
    #|Hour(9)
  ))
  inspect(@src.parse_tz_offset("+09"), content=(
    #|Hour(9)
  ))
  inspect(@src.parse_tz_offset("-5"), content=(
    #|Hour(-5)
  ))
}

///|
test "parse_tz_offset: HHMM and HH:MM" {
  inspect(@src.parse_tz_offset("+0900"), content=(
    #|Hour(9)
  ))
  inspect(@src.parse_tz_offset("+09:00"), content=(
    #|Hour(9)
  ))
  inspect(@src.parse_tz_offset("+0530"), content=(
    #|Min(330)
  ))
  inspect(@src.parse_tz_offset("+05:30"), content=(
    #|Min(330)
  ))
}

///|
test "parse_tz_offset: duration format" {
  inspect(@src.parse_tz_offset("5h30m"), content=(
    #|Min(330)
  ))
  inspect(@src.parse_tz_offset("+5h30m"), content=(
    #|Min(330)
  ))
  inspect(@src.parse_tz_offset("-5h"), content=(
    #|Hour(-5)
  ))
  inspect(@src.parse_tz_offset("9h"), content=(
    #|Hour(9)
  ))
}

///|
test "parse_tz_offset: zero offset" {
  inspect(@src.parse_tz_offset("0"), content=(
    #|Utc
  ))
  inspect(@src.parse_tz_offset("+0"), content=(
    #|Utc
  ))
  inspect(@src.parse_tz_offset("-00:00"), content=(
    #|Utc
  ))
}

///|
test "parse_tz_offset: negative minutes" {
  inspect(@src.parse_tz_offset("-5:30"), content=(
    #|Min(-330)
  ))
  inspect(@src.parse_tz_offset("-0530"), content=(
    #|Min(-330)
  ))
}
