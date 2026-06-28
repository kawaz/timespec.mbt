///|
fn range_test_now() -> UInt64 {
  1_000_000UL // 1,000,000 ms = 1000 seconds
}

///|
test "parse_range: since single value" {
  // since のみ与えた場合、until は None のまま。default_sign=Minus により "5m" は
  // 過去方向 (Relative(now, -300_000ms)) として解決。until 不在は「無限大方向」を
  // 意味し空集合に縮退しない (= range の片端だけが指定された自然な意味)。
  let r = @timespec.parse_range(
    since="5m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|None
    ),
  )
}

///|
test "parse_range: until single value" {
  // since の対称ケース。until 単体指定で since=None、until のみ Relative 解決。
  // since 不在は「過去無限大から」を意味する (= 片端指定の対称性確認)。
  let r = @timespec.parse_range(
    until="5m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|None
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
}

///|
test "parse_range: both relative independent" {
  // 両方 Relative の場合、anchor 解決は発生せず各自 now 基準で独立解決する。
  // since=now-5m=700_000、until=now-3m=820_000。「同種は独立」の原則で、
  // until を since 起点に解釈する誘惑を排除する (= 入力に @ marker が無い限り
  // 暗黙の依存関係は作らない、DR-0006 parse_range 設計)。
  let r = @timespec.parse_range(
    since="5m",
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: mixed - until absolute anchor" {
  // Mixed (片方 Absolute / 片方 Relative) → @ 側を anchor として固定し、
  // Relative 側を anchor 起点で解決する。"5m~@3m" では until が Absolute なので
  // anchor、since=until-5m=820_000-300_000=520_000。@ marker は「ここを固定点
  // にせよ」という user intent シグナル (DR-0007 Phase 2 @ marker 意味論)。
  let r = @timespec.parse_range(
    since="5m",
    until="@3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(520000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Absolute(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: both absolute independent" {
  // 両方 Absolute の場合も「同種は独立解決」原則が働き、相互依存しない。
  // both-relative ケースと対称: 同じ種類が並んだら anchor 概念は不要なので、
  // 各自 now 基準で解決。Absolute フラグは re-serialize 時に意図 (= user が @
  // を付けた事実) を保存するためで、計算経路は Relative と同じ (DR-0006)。
  let r = @timespec.parse_range(
    since="@5m",
    until="@3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Absolute(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Absolute(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: @ with explicit sign" {
  // @ marker と明示符号 (+) は直交する。@ は「Absolute フラグ」を立てるだけで、
  // 符号方向 (過去/未来) は別軸。until="@+3m" → Absolute(now+3m, +180_000)。
  // default_sign=Minus でも明示 + が優先される (= 明示符号は default を上書き)。
  let r = @timespec.parse_range(
    since="@5m",
    until="@+3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Absolute(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Absolute(EpochTime(1180000), Duration(180000)))
    ),
  )
}

///|
test "parse_range: swap" {
  // swap=true は since/until の epoch 比較で since > until のとき自動入替。
  // 入力 since=3m (now-180_000=820_000), until=5m (now-300_000=700_000) は
  // 過去方向で since が新しい → swap して since=700_000, until=820_000 とする。
  // 「user が前後逆に書いてしまっても自然な range として解釈する」救済機能。
  let r = @timespec.parse_range(
    since="3m",
    until="5m",
    now=range_test_now,
    default_sign=Minus,
    swap=true,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: empty since" {
  // since 引数省略時の until-only 解決確認。"until single value" との違いは
  // duration 値 (3m vs 5m) のみで本質は同じだが、since 省略時に余計な副作用
  // (例: default 値で埋める / エラーになる等) が無いことを再確認するケース。
  let r = @timespec.parse_range(
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|None
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: explicit positive sign on until" {
  // 明示符号 (+) は default_sign を上書きする。default_sign=Minus でも
  // "+3m" は未来方向に解決される (Duration(+180_000), epoch=now+3m=1_180_000)。
  // since="5m" は符号なしなので default_sign=Minus が適用され過去方向。
  // → 同じ range 内で過去 since・未来 until を混在できることを担保。
  let r = @timespec.parse_range(
    since="5m",
    until="+3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(1180000), Duration(180000)))
    ),
  )
}

///|
test "parse_range: explicit negative sign on until" {
  // 明示符号 (-) と default_sign=Minus が一致するケース。default sign と
  // 明示 sign が一致しても結果は同じになるべき (= 冪等)。"+" のケースとの
  // 対称性確認: 明示符号が default を「上書きする」のではなく「指定する」
  // 意味論であることを担保 (符号なし=default に委譲、符号あり=明示で固定)。
  let r = @timespec.parse_range(
    since="5m",
    until="-3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: mixed - since absolute anchor" {
  // Mixed の since 側が Absolute のケース (mixed-until-absolute-anchor の対称)。
  // since=@5m が anchor として固定され、until=3m は since 起点で解決:
  // until=since-3m=700_000-180_000=520_000。「@ 側が anchor」原則は左右対称で、
  // 入力位置 (since か until か) に依存しない (DR-0007 Phase 2)。
  let r = @timespec.parse_range(
    since="@5m",
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Absolute(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(520000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: mixed - until absolute, since relative" {
  // mixed-until-absolute-anchor と同一構成 (since="5m", until="@3m") の重複検証。
  // 「Mixed → absolute 側が anchor」原則を別文脈で再宣言するためのケース。
  // 同じ入力で同じ結果 (since=520_000, until=820_000) を担保する regression。
  let r = @timespec.parse_range(
    since="5m",
    until="@3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Relative(EpochTime(520000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Absolute(EpochTime(820000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: mixed - since absolute, until relative (until context equivalent)" {
  // mixed-since-absolute-anchor (@5m~3m) と同一入力の重複検証ケース。
  // since=Absolute(now-5m)=700_000 が anchor、until=since-3m=520_000。
  // テスト名の "until context equivalent" は「until を anchor 起点で
  // 解釈する文脈になる」ことを示す (= anchor が since 側でも解決経路は同型)。
  let r = @timespec.parse_range(
    since="@5m",
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content=(
      #|Some(Absolute(EpochTime(700000), Duration(-300000)))
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|Some(Relative(EpochTime(520000), Duration(-180000)))
    ),
  )
}

///|
test "parse_range: both empty returns empty range" {
  // since/until/input いずれも未指定 → エラーにせず空 range {None, None} を返す。
  // 「指定なしは全範囲」を意味し、呼び出し側で条件未設定を扱いやすくする。
  // (no_arguments テストとの違い: こちらは now/default_sign は与えている)
  let r = @timespec.parse_range(now=range_test_now, default_sign=Minus)
  debug_inspect(
    r.since,
    content=(
      #|None
    ),
  )
  debug_inspect(
    r.until,
    content=(
      #|None
    ),
  )
}

///|
test "parse_range: invalid input raises error" {
  // パース不能な文字列は黙って None にせず必ず例外を出す。silent fallback は
  // user の typo (例: "invalid_xyz" を意図した時刻として受理してしまう) を
  // 隠蔽するため禁則 (fail-fast 方針)。"noraise" 分岐に落ちたら test 失敗。
  try
    @timespec.parse_range(
      since="invalid_xyz",
      now=range_test_now,
      default_sign=Minus,
    )
    |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error for invalid input")
  }
}

///|
test "parse_range: input~ with tilde" {
  // チルダ区切り input="5m~3m" は since="5m", until="3m" と等価。
  // 1 引数で range を表現したい場面 (CLI の単一 --time フラグ等) を
  // 救済する syntactic sugar で、2 引数方式と意味論的に完全一致を担保。
  let a = @timespec.parse_range(
    since="5m",
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  let b = @timespec.parse_range(
    input="5m~3m",
    now=range_test_now,
    default_sign=Minus,
  )
  assert_true(a == b)
}

///|
test "parse_range: input~ since only (5d~)" {
  // チルダ末尾形式 "5d~" は「since のみ・until 無制限」を意味し、
  // since="5d" と until 未指定の 2 引数形式に等価。チルダ位置で
  // since/until のどちらが指定されたかを構文的に区別 (= 前=since、後=until)。
  let a = @timespec.parse_range(
    since="5d",
    now=range_test_now,
    default_sign=Minus,
  )
  let b = @timespec.parse_range(
    input="5d~",
    now=range_test_now,
    default_sign=Minus,
  )
  assert_true(a == b)
}

///|
test "parse_range: input~ until only (~3m)" {
  // チルダ先頭形式 "~3m" は "5d~" の対称ケース: until のみ指定。
  // since 不在 (= 過去無限大から) を 1 引数で表現。位置による意味
  // 分離は user の意図を構文だけで読み取れる利点がある (= 順序自由度なし)。
  let a = @timespec.parse_range(
    until="3m",
    now=range_test_now,
    default_sign=Minus,
  )
  let b = @timespec.parse_range(
    input="~3m",
    now=range_test_now,
    default_sign=Minus,
  )
  assert_true(a == b)
}

///|
test "parse_range: input~ no tilde (since only)" {
  // チルダなし input="5m" は since="5m" と等価 (= "5m~" と同じ意味)。
  // 単一 timespec を range として与える最頻ケースを救済。チルダ省略時の
  // default は since 側 (= 範囲の起点指定が CLI で典型的なため)。
  let a = @timespec.parse_range(
    since="5m",
    now=range_test_now,
    default_sign=Minus,
  )
  let b = @timespec.parse_range(
    input="5m",
    now=range_test_now,
    default_sign=Minus,
  )
  assert_true(a == b)
}

///|
test "parse_range: input and since/until together is error" {
  // input と since/until の併用は禁止 (= 同じ情報を 2 経路で受け取ると
  // どちらを優先するかで意味が割れる)。silent な優先選択 (例: input 勝ち)
  // にせず明示的に error を上げて user に修正を促す。"either-or" 制約は
  // CLI argument schema レベルで保証されるべきだが、ライブラリ側でも防御。
  try
    @timespec.parse_range(
      input="99d~99d",
      since="5m",
      now=range_test_now,
      default_sign=Minus,
    )
    |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error when input and since/until both given")
  }
}

///|
test "parse_range: no arguments" {
  // 引数完全省略 (now / default_sign すら無し) でも error にならず
  // 空 range を返す。「何も指定しない時の振る舞いはエラーではなく空」
  // という最小契約 (= now が必要なケース=実際に時刻解決が必要な時だけ)。
  let r = @timespec.parse_range()
  debug_inspect(
    r,
    content=(
      #|{ since: None, until: None }
    ),
  )
}
