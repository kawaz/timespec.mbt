///|
test "Duration::from_ns positive" {
  inspect(Duration::from_ns(0L), content=(
    #|Ms(0)
  ))
  inspect(Duration::from_ns(1_000_000L), content=(
    #|Ms(1)
  ))
  inspect(Duration::from_ns(2_100_000L), content=(
    #|MsNs(2, 100000)
  ))
  inspect(Duration::from_ns(5_400_000_000_000L), content=(
    #|Ms(5400000)
  ))
}

///|
test "Duration::from_ns with sub-ms" {
  inspect(Duration::from_ns(1_000L), content=(
    #|MsNs(0, 1000)
  ))
  inspect(Duration::from_ns(999_999L), content=(
    #|MsNs(0, 999999)
  ))
  inspect(Duration::from_ns(500_000L), content=(
    #|MsNs(0, 500000)
  ))
}

///|
test "Duration::from_ns negative" {
  inspect(Duration::from_ns(-300_000_000_000L), content=(
    #|Ms(-300000)
  ))
  inspect(Duration::from_ns(-2_100_000L), content=(
    #|MsNs(-3, 900000)
  ))
}

///|
test "Duration::to_ns roundtrip" {
  let d = Duration::from_ns(2_100_000L)
  inspect(d.to_ns(), content=(
    #|2100000
  ))
}
