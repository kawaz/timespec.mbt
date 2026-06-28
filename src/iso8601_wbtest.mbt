///|
test "detect_tz_suffix: trailing Z" {
  // ISO 8601 Pattern 1: 末尾 Z は UTC の正式表記。最もシンプルな検出経路。
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00Z"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: trailing z (lowercase)" {
  // 小文字 z も UTC として受理 (= 大文字小文字を区別しない、ISO 8601 実装慣行)。
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00z"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: +HH:MM" {
  // Pattern 2: 末尾 6 文字の ±HH:MM 形式。Hour 単位ぴったりなので Hour(9) で表現。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00+09:00"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: -HH:MM" {
  // 分単位の半端な offset (-05:30 = -330 min) は Min variant で保持。
  // Hour で表せない精度は専用 variant に振り分ける設計 (= 情報損失なし)。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-05:30"),
    content="Some(Min(-330))",
  )
}

///|
test "detect_tz_suffix: +HHMM" {
  // Pattern 3: コロンなしの ±HHMM (末尾 5 文字)。ISO 8601 basic 形式の TZ。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00+0900"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: -HHMM" {
  // basic 形式でも分単位の半端 offset は Min variant に振り分け。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-0530"),
    content="Some(Min(-330))",
  )
}

///|
test "detect_tz_suffix: +00:00 normalizes to Utc" {
  // +00:00 は意味的に UTC と等価なので Hour(0) でなく Utc に正規化する
  // (= 後段の TZ 比較・表示で UTC 扱いを一意化)。
  debug_inspect(
    detect_tz_suffix("2024-01-01T00:00:00+00:00"),
    content="Some(Utc)",
  )
}

///|
test "detect_tz_suffix: no TZ (date only)" {
  // 日付のみ (時刻成分なし) は TZ 不在として None を返す。
  // 重要: 末尾の `-01` を Pattern 4 (= -H) と誤認しないこと
  // (= Pattern 4 はコロン必須なのでここはガード成立、DR-0009)。
  debug_inspect(detect_tz_suffix("2024-01-01"), content="None")
}

///|
test "detect_tz_suffix: no TZ (datetime without TZ)" {
  // datetime に TZ サフィックスが付いていなければ None (= local time 扱いを後段に委ねる)。
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00"), content="None")
}

///|
test "detect_tz_suffix: no TZ (locale format)" {
  // ISO 8601 ではない locale 表記には TZ サフィックスが現れない。
  // parser 非依存の検出器でも誤検出しないことを確認 (= 末尾が日本語文字でも安全)。
  debug_inspect(detect_tz_suffix("11月12日 15:00"), content="None")
}

///|
test "detect_tz_suffix: empty string" {
  // 空文字列は境界ケース。クラッシュせず None を返すこと。
  debug_inspect(detect_tz_suffix(""), content="None")
}

///|
test "detect_tz_suffix: with milliseconds and Z" {
  // ms 小数部があっても Z は末尾検出で問題なく拾える (= Z はサフィックス 1 文字判定)。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00.500Z"),
    content="Some(Utc)",
  )
}

///|
test "detect_tz_suffix: with milliseconds and +HH:MM" {
  // 小数秒 + ±HH:MM の組み合わせ。後ろから 6 文字 (+09:00) 切り出しで成立。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00.500+09:00"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: +HH (short)" {
  // Pattern 4 (短い TZ): ±HH。datetime 内のコロン有 + 符号前が digit
  // という安全条件下でのみ TZ と判定する (DR-0009 Pattern 4)。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00+09"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: -HH (short)" {
  // 負方向の短い TZ。コロン有の前提が成立しているので末尾 -05 を TZ と判定。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-05"),
    content="Some(Hour(-5))",
  )
}

///|
test "detect_tz_suffix: +H (single digit)" {
  // Pattern 4 の極限ケース: 1 桁 ±H も TZ として受理 (例: +9 = +09:00)。
  // 部分日付 (YYYY-M) を禁止した DR-0009 によりこの拡張が安全に成立する。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00+9"),
    content="Some(Hour(9))",
  )
}

///|
test "detect_tz_suffix: -H (single digit)" {
  // 負方向 1 桁。-5 を月 (= 部分日付 YYYY-M) と誤読しないため、
  // DR-0009 で部分日付を禁止して曖昧性を排除している。
  debug_inspect(
    detect_tz_suffix("2024-01-01T12:00:00-5"),
    content="Some(Hour(-5))",
  )
}

///|
test "detect_tz_suffix: +0 normalizes to Utc" {
  // +0 も意味的 UTC なので Hour(0) でなく Utc に正規化 (+00:00 ケースと整合)。
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00+0"), content="Some(Utc)")
}

///|
test "detect_tz_suffix: date-like suffix not mistaken for TZ" {
  // 中核ガード: フル日付 (YYYY-MM-DD) の末尾 -DD を TZ と誤認しないこと。
  // Pattern 4 の安全条件「コロン有」が成立しないため None。
  // この保証は DR-0009 で部分日付 (YYYY / YYYY-MM) を禁止した前提で機能する。
  debug_inspect(detect_tz_suffix("2024-01-15"), content="None")
  debug_inspect(detect_tz_suffix("2024-01-01"), content="None")
  debug_inspect(detect_tz_suffix("2024-12-31"), content="None")
}

///|
test "detect_tz_suffix: date-only with no time never detects short TZ" {
  // basic 形式の日付 (YYYYMMDD) でも短い TZ を検出しない。コロン無しガード成立。
  debug_inspect(detect_tz_suffix("20240115"), content="None")
}

///|
test "saturating_add: normal addition" {
  // 通常域 (= overflow しない範囲) では通常加算と完全一致することを確認。
  // 正+正 / 負+負 / 正+負 (打消し) / ゼロ加算 の同値分割代表を確認。
  debug_inspect(saturating_add(1L, 2L), content="3")
  debug_inspect(saturating_add(-1L, -2L), content="-3")
  debug_inspect(saturating_add(100L, -50L), content="50")
  debug_inspect(saturating_add(0L, 0L), content="0")
}

///|
test "saturating_add: positive overflow clamps to MAX_VALUE" {
  // 正方向 overflow は MAX_VALUE に飽和 (= wrap-around しない)。
  // epoch ms の演算で時刻が遠未来へ飛んでも値を破壊しないための保護機構。
  // MAX_VALUE + 1 would overflow; should clamp
  debug_inspect(
    saturating_add(@int64.MAX_VALUE, 1L),
    content="9223372036854775807",
  )
  // MAX_VALUE + large positive should also clamp
  debug_inspect(
    saturating_add(@int64.MAX_VALUE, 3600000L),
    content="9223372036854775807",
  )
  // 境界近傍ケース: 結果が MAX を跨ぐ加算でも飽和側に倒れる
  // (= overflow の検出が「結果値の比較」ではなく事前判定で機能していること)。
  // Near MAX_VALUE: (MAX_VALUE - 1000) + 3600000 overflows
  debug_inspect(
    saturating_add(@int64.MAX_VALUE - 1000L, 3600000L),
    content="9223372036854775807",
  )
}

///|
test "saturating_add: negative overflow clamps to MIN_VALUE" {
  // 負方向の対称ケース: MIN_VALUE に飽和。正負両方向で同じ保護が効くこと。
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
  // 境界ぴったりで overflow しないケース (= off-by-one 防止)。
  // 「飽和が起きるべきでない場面」で誤って飽和させないことを保証する。
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
  // スコープ外: 文字列ベースの TZ 名 (JST / UTC / EST 等) は対応しない
  // (= ISO 8601 サフィックス記法のみ検出。名前ベース TZ は parser 本体の責務)。
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00 JST"), content="None")
  debug_inspect(detect_tz_suffix("2024-01-01T12:00:00 UTC"), content="None")
  // Z 単独 / ±HH:MM 単独は TZ サフィックスとして妥当 (= datetime 本体は別途扱う前提)。
  debug_inspect(detect_tz_suffix("Z"), content="Some(Utc)")
  debug_inspect(detect_tz_suffix("+09:00"), content="Some(Hour(9))")
  // 短形式 +H / -H はコロン必須ガードにより、コロン無し入力では検出されない
  // (= "+9" 単独は数値リテラル扱い、Pattern 4 安全条件不成立、DR-0009)。
  debug_inspect(detect_tz_suffix("+9"), content="None")
}
