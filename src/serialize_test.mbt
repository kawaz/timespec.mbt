///|
test "to_cli_string: Absolute" {
  // Absolute は「結果としての絶対時刻」を ISO 8601 UTC で再シリアライズする。
  // EpochTime(1704067200000) = 2024-01-01T00:00:00Z。Duration=0 のときは
  // 時刻部のみを返す (DR-0006 Absolute/Relative 意図保存)。
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(1704067200000L),
    @timespec.Duration(0L),
  ) // 2024-01-01T00:00:00Z
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"2024-01-01T00:00:00Z"
    ),
  )
}

///|
test "to_cli_string: Relative positive" {
  // Relative は「やり方 (= anchor からの符号付き duration)」を保存する型なので、
  // 再シリアライズでは EpochTime (anchor 解決結果) を捨てて Duration を符号付き
  // で出す。+5m は now+5m を表現した入力 (DR-0006 意図保存)。
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(1_300_000L),
    @timespec.Duration(300_000L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+5m"
    ),
  )
}

///|
test "to_cli_string: Relative negative" {
  // 負の Duration は "-" 符号で再シリアライズする (= "5m ago" を表現していた
  // 入力を符号付き形式で復元)。"+-5m" のような二重符号にしない。
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(700_000L),
    @timespec.Duration(-300_000L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"-5m"
    ),
  )
}

///|
test "to_cli_string: Relative zero" {
  // Duration=0 の Relative は "now" を表すが、Relative 型としての意図を
  // 保つため "+0s" と符号付きで返す (= 空文字や "0" にしない。Absolute と
  // 区別できる形を維持)。
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(1_000_000L),
    @timespec.Duration(0L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+0s"
    ),
  )
}

///|
test "to_cli_string: Relative large" {
  // 複数単位にまたがる Duration は h/m/s の組合せで分解出力される。
  // 5_400_000ms を "+1h30m" と最大単位優先で表現 (= "+90m" や "+5400000ms"
  // にしない、人間可読性優先)。
  // 1h30m = 5_400_000ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(5_400_000L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+1h30m"
    ),
  )
}

///|
test "format_duration: weeks and days" {
  // w/d も最大単位優先で分解する。777_600_000ms を "+1w2d" と出す
  // (= "+9d" にせず、ms 単位を超える上位単位 w まで使う)。
  // 1w2d = 604800000 + 172800000 = 777600000 ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(777_600_000L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+1w2d"
    ),
  )
}

///|
test "format_duration: all units" {
  // 全単位 (h/m/s/ms) を含む Duration が省略なく順序通り連結されることを
  // 確認。途中の単位が 0 でないので連結。順序が崩れたり単位飛ばしが
  // 起きないこと自体が format 仕様。
  // 1h30m45s500ms
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(5_445_500L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+1h30m45s500ms"
    ),
  )
}

///|
test "format_duration: ms only" {
  // 1 秒未満は ms 単位のみで表現。500ms を "+0s500ms" のように上位 0 を
  // 並べず "+500ms" と最小限の単位だけ出すことを確認。
  let ts : @timespec.TimeSpec = Relative(
    @timespec.EpochTime(0L),
    @timespec.Duration(500L),
  )
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"+500ms"
    ),
  )
}

///|
test "to_cli_string: Absolute with milliseconds" {
  // ms 精度を持つ EpochTime は ISO 8601 の小数秒 (.SSS) で表現する。
  // 0ms ちょうどなら時刻部のみ ("...:00Z")、ms があるなら ".500Z" を付ける
  // 境界 (= ms 部の有無で表記が分かれる) を確認。
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(1704067200500L),
    @timespec.Duration(0L),
  ) // .500
  debug_inspect(
    ts.to_cli_string(),
    content=(
      #|"2024-01-01T00:00:00.500Z"
    ),
  )
}

///|
test "format_duration: Int64.min_value does not overflow" {
  // Int64 境界ケース: 二の補数表現で Int64.MIN_VALUE は -MIN = MIN にラップ
  // するため、素朴な「絶対値を取って符号を付ける」実装はここで破綻する
  // (= "+0s" 等の誤出力 / オーバーフローループ)。format_duration はこの
  // edge case を安全に処理する必要があり、その境界を保証する test。
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
  debug_inspect(
    result[:1].to_owned(),
    content=(
      #|"-"
    ),
  )
  // Should NOT start with "+-" or be "+0s" (which would indicate overflow)
  assert_true(result != "+0s")
  assert_true(result != "+-0s")
  // The magnitude should be 9223372036854775808ms decomposed into units.
  // 9223372036854775808 ms = 15250284452w3d7h12m55s808ms
  // But since remain is set to Int64.max_value (off by 1ms), we add that 1ms back.
  // Let's just verify it parses to a reasonable negative duration string.
  debug_inspect(
    result,
    content=(
      #|"-15250284452w3d7h12m55s808ms"
    ),
  )
}

///|
test "to_cli_string: with custom epoch" {
  // カスタム epoch (= Snowflake 等の独自基点) で EpochTime(0) を ISO 8601 に
  // 変換するとき、Unix epoch ではなくカスタム epoch オフセットを足してから
  // 出力する必要がある。epoch=snowflake_epoch を渡すと EpochTime(0) は
  // 2010-11-04T01:42:54.657Z (Snowflake epoch そのもの) を返す (DR-0003)。
  // EpochTime ms=0 with Snowflake epoch → Unix ms = 0 + 1288834974657 → ISO 8601
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(0L),
    @timespec.Duration(0L),
  )
  let snowflake_epoch = @timespec.EpochTime(1288834974657L)
  debug_inspect(
    ts.to_cli_string(epoch=snowflake_epoch),
    content=(
      #|"2010-11-04T01:42:54.657Z"
    ),
  )
}
