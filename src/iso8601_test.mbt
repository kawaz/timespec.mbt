///|
test "parse_datetime: basic date" {
  // 日付のみ (YYYY-MM-DD) は TZ サフィックスなし時、make_parse_datetime に
  // 与えた default_tz_offset (= ここでは Utc) で解釈される。時刻部は 00:00:00。
  // 2024-01-01T00:00:00Z = 1704067200000ms (epoch)。
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024-01-01"),
    content=(
      #|Some(1704067200000)
    ),
  )
}

///|
test "parse_datetime: date with time" {
  // T 区切りの日時 (TZ サフィックスなし) は default_tz_offset で解釈される
  // (= Local default 方針 DR-0008 を make_parse_datetime の引数で上書き、
  // ここでは Utc 明示)。2024-01-01T12:00:00Z = 1704110400000ms。
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024-01-01T12:00:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with time and Z" {
  // 末尾 Z は UTC を明示する ISO 8601 サフィックス。default_parse_datetime
  // (= Local default) を使っても Z があれば Local を上書きして UTC 解釈に
  // なる (= 明示 TZ サフィックスが default より強い、DR-0009 detect_tz_suffix)。
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T12:00:00Z"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with timezone +09:00" {
  // +09:00 TZ サフィックスは UTC より 9 時間進んだローカル時刻を意味する。
  // 21:00 (+09:00) = 12:00 (UTC) なので 2024-01-01T12:00:00Z と同 epoch。
  // 末尾 +HH:MM がパーサに認識される (= partial date と曖昧化しないために
  // YMD 必須化、DR-0009)。
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T21:00:00+09:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: date with timezone -05:00" {
  // 負方向の TZ サフィックス (EST 想定): -05:00 は UTC より 5 時間遅れた
  // ローカル時刻。07:00 (-05:00) = 12:00 (UTC) で +09:00 ケースと同 epoch
  // に到達することを確認 (= 異なる TZ 表記から同一瞬間に解決される)。
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T07:00:00-05:00"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: slash separator" {
  // 日付の区切り文字として "-" 以外に "/" も許容 (= 人間がよく書く YYYY/MM/DD
  // 形式を受け入れる柔軟性)。意味は YYYY-MM-DD と同じく Local default 解釈。
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  debug_inspect(
    parse_utc("2024/01/01"),
    content=(
      #|Some(1704067200000)
    ),
  )
}

///|
test "parse_datetime: milliseconds" {
  // 小数秒 .500 をミリ秒として正しく加算する (= ms 精度の EpochTime に
  // 直接マップ、内部 Int64 ms 表現と整合)。秒整数部 + 500ms = 末尾 500。
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01T12:00:00.500Z"),
    content=(
      #|Some(1704110400500)
    ),
  )
}

///|
test "parse_datetime: space separator for T" {
  // ISO 8601 では日付/時刻の区切りは "T" だが、SQL 風の半角空白 " " も
  // 同等として受け入れる (= 人間入力の柔軟性、CLI --since の使い勝手)。
  debug_inspect(
    @timespec.default_parse_datetime("2024-01-01 12:00:00Z"),
    content=(
      #|Some(1704110400000)
    ),
  )
}

///|
test "parse_datetime: invalid returns None" {
  // 異常系: 完全に日付として読めない文字列、および空文字は None。
  // パース失敗を Option で表し例外を投げない (= 上位の parse_timespec が
  // 別経路 (duration / 相対指定) を試せるよう、軽量に失敗を返す方針)。
  debug_inspect(
    @timespec.default_parse_datetime("not-a-date"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @timespec.default_parse_datetime(""),
    content=(
      #|None
    ),
  )
}

///|
test "epoch_to_iso8601: basic UTC" {
  // 正方向: epoch_to_iso8601 のデフォルト出力は UTC (Z サフィックス) で
  // ISO 8601 標準形 (parse_datetime と round-trip 可能な書式)。
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L),
    content=(
      #|"2024-01-01T00:00:00Z"
    ),
  )
}

///|
test "epoch_to_iso8601: with milliseconds" {
  // ms 単位の小数秒があれば .NNN 形式で出力 (= 末尾 500ms → ".500Z")。
  // ms 部 0 のときは省略 (上のケース)、非 0 のときだけ表示する精度保存設計。
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200500L),
    content=(
      #|"2024-01-01T00:00:00.500Z"
    ),
  )
}

///|
test "epoch_to_iso8601: with Hour offset" {
  // tz_offset=Hour(9) を渡すと JST 相当の表示 (= 同じ epoch を別 TZ で
  // 文字列化、瞬間は不変)。時刻部に offset 分を加算した上で末尾に +09:00。
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L, tz_offset=Hour(9)),
    content=(
      #|"2024-01-01T09:00:00+09:00"
    ),
  )
}

///|
test "epoch_to_iso8601: with Min offset" {
  // 分単位の TZ (= IST, ネパール時間など 30 分/45 分刻みの非整時間オフセット)
  // を Min(330) で表現できる。出力は +05:30 形式 (= +HH:MM)。Hour とは別の
  // variant を持つことで分単位精度を保持 (TzOffset の設計)。
  debug_inspect(
    @timespec.epoch_to_iso8601(1704067200000L, tz_offset=Min(330)),
    content=(
      #|"2024-01-01T05:30:00+05:30"
    ),
  )
}

///|
test "epoch_to_iso8601: epoch zero" {
  // 境界: Unix epoch 原点 (0ms) は 1970-01-01T00:00:00Z。
  // EpochTime(0L) は DR-0003 の Unix epoch デフォルトの基点と一致する。
  debug_inspect(
    @timespec.epoch_to_iso8601(0L),
    content=(
      #|"1970-01-01T00:00:00Z"
    ),
  )
}

///|
test "epoch_to_iso8601: TZ offset does not cause Int64 overflow" {
  // 境界: TZ offset 加算が Int64 をオーバーフローしても、saturating_add で
  // 飽和させることで「符号反転して年が負になる」破壊的な崩れを防ぐ不変条件。
  // 通常使用域 (large but valid) と Int64 境界域の両方でテスト (= 同じ epoch
  // でも UTC と +1h で出力の年符号が一致することを invariant として確認)。
  // Use a large-but-valid epoch (year ~5879610, within Int32 arithmetic range).
  // 185480424979200000 ms ≈ 2146764178 days from epoch.
  // With +01:00 offset (+3600000ms), total_days stays safe (2146764178).
  let large_epoch = 185480424979200000L
  let result_utc = @timespec.epoch_to_iso8601(large_epoch)
  let result_tz = @timespec.epoch_to_iso8601(large_epoch, tz_offset=Hour(1))
  // Both should produce valid far-future dates with positive years
  debug_inspect(result_utc.has_prefix("-"), content="false")
  debug_inspect(result_tz.has_prefix("-"), content="false")
  // Now test values near Int64 boundaries where TZ addition would overflow.
  // Int64.MAX_VALUE - 1000 + Hour(1) offset (+3600000ms) overflows Int64.
  // Without saturating_add: wraps to a large negative, producing a sign-flipped year.
  // With saturating_add: clamps to Int64.MAX_VALUE, avoiding the sign flip.
  // (The output is still garbled by downstream Int32 truncation, but the overflow
  // from TZ addition no longer makes it dramatically worse.)
  let near_max = @int64.MAX_VALUE - 1000L
  let near_max_utc = @timespec.epoch_to_iso8601(near_max)
  let near_max_tz = @timespec.epoch_to_iso8601(near_max, tz_offset=Hour(1))
  // Key invariant: TZ offset addition should not flip the year's sign.
  // Both should have the same sign (both are garbled the same way).
  debug_inspect(
    near_max_utc.has_prefix("-") == near_max_tz.has_prefix("-"),
    content="true",
  )
  // Negative direction: Int64.MIN_VALUE + 1000 with Hour(-1) would underflow.
  let near_min = @int64.MIN_VALUE + 1000L
  let near_min_utc = @timespec.epoch_to_iso8601(near_min)
  let near_min_tz = @timespec.epoch_to_iso8601(near_min, tz_offset=Hour(-1))
  debug_inspect(
    near_min_utc.has_prefix("-") == near_min_tz.has_prefix("-"),
    content="true",
  )
}

///|
test "epoch_to_iso8601: negative epoch (pre-1970)" {
  // 境界: 負の epoch (1970 以前) も正しく日付の繰り下がりを行う。
  // -1000ms は epoch 直前 1 秒 = 1969-12-31T23:59:59Z。日 / 月 / 年すべての
  // 借り処理が必要なエッジケース (= 年境界 + 月境界 + 日境界の同時越え)。
  debug_inspect(
    @timespec.epoch_to_iso8601(-1000L),
    content=(
      #|"1969-12-31T23:59:59Z"
    ),
  )
}

///|
test "datetime normalization: day overflow" {
  // 範囲外の日 (11 月 32 日) は翌月へ正規化 (= JS Date 同様、入力エラーで
  // 拒否せずに繰り上げて受け入れる方針)。これにより "今日 + N 日" のような
  // 計算結果をそのまま文字列で投げ込んでも壊れない。
  // 2026-11-32 → 2026-12-02 (11月は30日)
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-11-32")
  let b = parse_utc("2026-12-02")
  debug_inspect(
    a,
    content=(
      #|Some(1796169600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1796169600000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: month overflow" {
  // 月の繰り上げ正規化 (= 13 月 → 翌年 1 月)。日と同様、範囲外を拒否せず
  // 繰り上げる方針を月レイヤでも一貫して適用。
  // 2026-13-01 → 2027-01-01
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-13-01")
  let b = parse_utc("2027-01-01")
  debug_inspect(
    a,
    content=(
      #|Some(1798761600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1798761600000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: second overflow" {
  // 秒の繰り上げ正規化 (= うるう秒に近い表現 13:50:60 を 13:51:00 とする)。
  // 入力柔軟性のため日 / 月 / 時 / 分 / 秒すべての階層で同じ繰り上げ規則。
  // 13:50:60 → 13:51:00
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-01-01T13:50:60")
  let b = parse_utc("2026-01-01T13:51:00")
  debug_inspect(
    a,
    content=(
      #|Some(1767275460000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1767275460000)
    ),
  )
  assert_true(a == b)
}

///|
test "datetime normalization: hour overflow" {
  // 時の繰り上げ正規化が日境界を跨ぐケース (= 25:00 → 翌日 01:00)。
  // 階層を超えた繰り上げ伝搬 (時 → 日) が正しく動くことを確認。
  // 25:00:00 → 翌日 01:00:00
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  let a = parse_utc("2026-01-01T25:00:00")
  let b = parse_utc("2026-01-02T01:00:00")
  debug_inspect(
    a,
    content=(
      #|Some(1767315600000)
    ),
  )
  debug_inspect(
    b,
    content=(
      #|Some(1767315600000)
    ),
  )
  assert_true(a == b)
}

///|
test "epoch_to_iso8601 roundtrip" {
  // parse → epoch_to_iso8601 で同一文字列に戻ること (= 標準形のみで構成された
  // 入力は再シリアライズで形が変わらない、可逆性の保証)。CLI で「正規化後の
  // 文字列を再入力できる」ための基礎不変条件。
  let epoch = @timespec.default_parse_datetime("2024-06-15T10:30:45Z")
  match epoch {
    Some(ms) =>
      debug_inspect(
        @timespec.epoch_to_iso8601(ms),
        content=(
          #|"2024-06-15T10:30:45Z"
        ),
      )
    None => assert_true(false)
  }
}

///|
test "parse flexible date formats" {
  // 人間入力の柔軟性: ゼロパディング省略 / 区切り文字違い / 区切り省略を
  // すべて同一値に正規化することを確認。CLI で typing コストを下げるため、
  // strict ISO 形に縛らず複数表記を受け入れる方針。
  // 1-2桁の月日
  let a = @timespec.default_parse_datetime("2026-3-1")
  let b = @timespec.default_parse_datetime("2026-03-01")
  assert_true(a == b)
  // スラッシュ + 1桁
  let c = @timespec.default_parse_datetime("2026/3/1")
  assert_true(a == c)
  // 1桁時分秒
  let d = @timespec.default_parse_datetime("2026-3-1T9:5:3")
  let e = @timespec.default_parse_datetime("2026-03-01T09:05:03")
  assert_true(d == e)
  // 区切りなし (YYYYMMDD)
  let f = @timespec.default_parse_datetime("20260301")
  assert_true(a == f)
}

///|
test "parse compact datetime formats" {
  // ISO 8601 basic format (区切り省略形 YYYYMMDDTHHMMSS) を受け入れる。
  // log タイムスタンプや filename 由来の値が直接渡せることを保証する。
  // T と空白、Z 付き / 秒省略の各組合せが extended 形と同等になる。
  let parse_utc = @timespec.make_parse_datetime(default_tz_offset=Utc)
  // YYYYMMDDTHHmmss
  let b = parse_utc("20260301T120000")
  let c = parse_utc("2026-03-01T12:00:00")
  debug_inspect(
    b,
    content=(
      #|Some(1772366400000)
    ),
  )
  assert_true(b == c)
  // YYYYMMDDTHHmmssZ
  let d = parse_utc("20260301T120000Z")
  assert_true(d == c)
  // YYYYMMDD HHmmss
  let e = parse_utc("20260301 120000")
  assert_true(e == c)
  // YYYYMMDDTHHmm (秒なし)
  let f = parse_utc("20260301T1200")
  let g = parse_utc("2026-03-01T12:00:00")
  assert_true(f == g)
}

///|
test "parse partial datetime: year-only and year-month are rejected" {
  // 部分日付 (YYYY 単独 / YYYY-MM / YYYYMM) は禁止し None を返す。
  // 理由: "2026-03" は YYYY-MM とも YYYY + TZ オフセット "-03" とも読めて
  // しまうため、構文の曖昧性を排除するために YMD 必須化した (DR-0009)。
  // YYYY 単独も「単純な数値リテラル」と区別できないため同じ理由で拒否。
  debug_inspect(@timespec.default_parse_datetime("2026"), content="None")
  debug_inspect(@timespec.default_parse_datetime("202603"), content="None")
  debug_inspect(@timespec.default_parse_datetime("2026-03"), content="None")
}

///|
test "datetime normalization: month=13 wraps to next year" {
  // 月の繰り上げが年境界を跨ぐ最小ケース (= 13 月 → 翌年 1 月)。
  // 上の "month overflow" と重複するが、default パーサ経由の動作を
  // 別解像度で確認 (= make_parse_datetime と default_parse_datetime の両経路)。
  let a = @timespec.default_parse_datetime("2024-13-01")
  let b = @timespec.default_parse_datetime("2025-01-01")
  assert_true(a == b)
}

///|
test "datetime normalization: month=0 wraps to previous year" {
  // 負方向の繰り下げ正規化 (= 0 月 → 前年 12 月)。月の繰り上げと同じ
  // 規則を 0 以下に対しても対称適用 (= 加算/減算で対称な算術になる)。
  let a = @timespec.default_parse_datetime("2024-00-01")
  let b = @timespec.default_parse_datetime("2023-12-01")
  assert_true(a == b)
}

///|
test "datetime normalization: Feb 30 in leap year" {
  // 閏年 2 月の境界: 2024 は閏年なので 2 月は 29 日まで。30 日目は翌月 1 日。
  // 月ごとの日数差 (2 月の閏年判定) が日繰り上げに正しく反映されることを
  // 確認 (= 28/29/30/31 の月別判定が下流の繰り上げに効いている)。
  let a = @timespec.default_parse_datetime("2024-02-30")
  let b = @timespec.default_parse_datetime("2024-03-01")
  assert_true(a == b)
}

///|
test "datetime normalization: hour=25" {
  // Z 付き入力でも時の繰り上げ正規化が同じく適用されることを確認
  // (= TZ サフィックスの有無で正規化規則が変わらない)。
  let a = @timespec.default_parse_datetime("2024-01-01T25:00:00Z")
  let b = @timespec.default_parse_datetime("2024-01-02T01:00:00Z")
  assert_true(a == b)
}

///|
test "datetime normalization: minute=60" {
  // 分の繰り上げ正規化 (= 60 分 → 次の時)。Z 付き入力での確認。
  // 階層 (時/分/秒) の各レイヤで同じ規則が機能していることの網羅。
  let a = @timespec.default_parse_datetime("2024-01-01T12:60:00Z")
  let b = @timespec.default_parse_datetime("2024-01-01T13:00:00Z")
  assert_true(a == b)
}

///|
test "parse_datetime: empty string returns None" {
  // 異常系: 空文字は None (= 上位パーサが「日付候補ではない」と即座に判定
  // して次の候補に進めるため、例外でなく Option で失敗を表す)。
  debug_inspect(@timespec.default_parse_datetime(""), content="None")
}

///|
test "parse time-only formats" {
  // 時刻のみ (HH:MM, HH:MM:SS, HH:MM:SS.mmm, HH:MM+TZ) は日付部を
  // 1970-01-01 として補完する (= epoch zero 日に時刻部のみ差し込む規約)。
  // partial date 禁止 (DR-0009) と矛盾しないのは、時刻のみは "HH:MM" のような
  // コロン区切りで判別可能なため、partial date 構文との曖昧性が無いから。
  // HH:MM
  let a = @timespec.default_parse_datetime("10:30")
  let b = @timespec.default_parse_datetime("1970-01-01T10:30:00")
  assert_true(a == b)
  // HH:MM:SS
  let c = @timespec.default_parse_datetime("10:30:45")
  let d = @timespec.default_parse_datetime("1970-01-01T10:30:45")
  assert_true(c == d)
  // HH:MM:SS.mmm
  let e = @timespec.default_parse_datetime("10:30:45.500")
  let f = @timespec.default_parse_datetime("1970-01-01T10:30:45.500")
  assert_true(e == f)
  // HH:MM with TZ
  let g = @timespec.default_parse_datetime("10:30+09:00")
  let h = @timespec.default_parse_datetime("1970-01-01T10:30:00+09:00")
  assert_true(g == h)
  // 00:00Z
  let i = @timespec.default_parse_datetime("00:00Z")
  debug_inspect(
    i,
    content=(
      #|Some(0)
    ),
  )
}
