///|
fn test_now() -> UInt64 {
  1_000_000UL // 1,000,000 ms = 1000 seconds
}

///|
test "parse_timespec: duration only (Relative)" {
  // duration 単独入力は Relative になる (= 「今から X 分前」のように now 相対の
  // やり方を保存)。datetime と組まない単体 duration は意図として「相対」なので
  // Absolute に潰さず Relative のまま残す (DR-0006 "結果 vs やり方")。
  debug_inspect(
    @timespec.parse_timespec("5m", now=test_now, default_sign=Minus),
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
}

///|
test "parse_timespec: @ prefix (Absolute)" {
  // @ marker は「結果としての時刻を確定」させるフラグ。@ 付きは Relative ではなく
  // Absolute として保存し、再シリアライズ時に「now 相対のやり方」を捨てて
  // 確定時刻で書き戻す (DR-0006 / DR-0007 Phase 2)。
  debug_inspect(
    @timespec.parse_timespec("@5m", now=test_now, default_sign=Minus),
    content=(
      #|Some(Absolute(EpochTime(700000), Duration(-300000)))
    ),
  )
}

///|
test "parse_timespec: @ suffix (Absolute)" {
  // 末尾 @ も先頭 @ と同等に Absolute フラグを立てる。配置位置で意味を変えると
  // @ の idempotency (= 任意位置 / 任意回でも一意な状態に収束) が壊れるため、
  // prefix/suffix を同じ Absolute 化として扱う (DR-0007 Phase 2, DR-0008)。
  debug_inspect(
    @timespec.parse_timespec("-5h@", now=test_now, default_sign=Minus),
    content=(
      #|Some(Absolute(EpochTime(-17000000), Duration(-18000000)))
    ),
  )
}

///|
test "parse_timespec: @-5h equals -5h@" {
  // @ の冪等性 (= idempotent marker) 確認: 同一 duration に対する @ 前置 / 後置で
  // 結果が一致する。位置を変えても意味が変わらないのが @ の規約 (DR-0008)。
  let a = @timespec.parse_timespec("@-5h", now=test_now, default_sign=Minus)
  let b = @timespec.parse_timespec("-5h@", now=test_now, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_timespec: datetime only (Absolute)" {
  // 完全な datetime (YMD + 時刻 + TZ) 単独入力は無条件に Absolute。now に依存しない
  // 「結果としての時刻」が確定しているため、Duration は 0 で保存する (DR-0007 Phase 4)。
  debug_inspect(
    @timespec.parse_timespec("2024-01-01T12:00:00Z", now=test_now),
    content=(
      #|Some(Absolute(EpochTime(1704110400000), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: datetime + duration" {
  // datetime 起点 + 末尾 duration (= datetime からのオフセット)。datetime が
  // anchor になるため結果は Absolute、Duration は加算分として保存し、
  // 再シリアライズで "datetime + offset" の書き方を復元できる (DR-0007 Phase 1/4)。
  debug_inspect(
    @timespec.parse_timespec("2024-01-01T12:00:00Z+5h30m", now=test_now),
    content=(
      #|Some(Absolute(EpochTime(1704130200000), Duration(19800000)))
    ),
  )
}

///|
test "parse_timespec: duration + datetime" {
  // 先頭 duration (符号なし) + datetime: 先頭 duration は default_sign の符号で
  // 解釈され、datetime からの「事前オフセット」として作用する。default_sign=Minus
  // なので -30m、結果として datetime より 30 分前を指す Absolute (DR-0007 Phase 1)。
  debug_inspect(
    @timespec.parse_timespec(
      "30m2024-01-01T12:00:00Z",
      now=test_now,
      default_sign=Minus,
    ),
    content=(
      #|Some(Absolute(EpochTime(1704108600000), Duration(-1800000)))
    ),
  )
}

///|
test "parse_timespec: duration + datetime + duration" {
  // 前後 duration が両方付くケース: 前は default_sign=Minus で -30m、後は明示
  // +5h30m。両 duration が datetime を起点に加算される (= マルチパスで前後を
  // 独立して抽出する設計、DR-0007 Phase 1)。合計 +5h00m = 18000000ms。
  debug_inspect(
    @timespec.parse_timespec(
      "30m2024-01-01T12:00:00Z+5h30m",
      now=test_now,
      default_sign=Minus,
    ),
    content=(
      #|Some(Absolute(EpochTime(1704128400000), Duration(18000000)))
    ),
  )
}

///|
test "parse_timespec: positive duration (Relative)" {
  // 明示符号 + の duration 単体は default_sign に依存せず + として解釈。
  // datetime/@ を伴わないので Relative (= 未来方向への相対指定)。
  debug_inspect(
    @timespec.parse_timespec("+5m", now=test_now),
    content=(
      #|Some(Relative(EpochTime(1300000), Duration(300000)))
    ),
  )
}

///|
test "parse_timespec: negative duration (Relative)" {
  // 明示符号 - の duration 単体: default_sign 不要、結果は now から 5 分前の Relative。
  // 上の "+5m" との対称ケース、明示符号は default_sign を override する。
  debug_inspect(
    @timespec.parse_timespec("-5m", now=test_now),
    content=(
      #|Some(Relative(EpochTime(700000), Duration(-300000)))
    ),
  )
}

///|
test "parse_timespec: invalid prefix before datetime" {
  // datetime 前に置けるのは duration (符号 + 数字 + 単位) のみ。任意の文字列を
  // prefix として黙認すると入力曖昧性が出るので、認識不能 prefix はパースエラー
  // にして「無効な前置文字列」を可視化する (DR-0007 Phase 1 が duration として
  // 消費できない残余を拒否)。
  try
    @timespec.parse_timespec("xxx2024-01-01T12:00:00Z", now=test_now) |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error for invalid prefix")
  }
}

///|
test "parse_timespec: garbage after datetime" {
  // datetime 後ろに置けるのも duration のみ。不正な末尾文字列を黙認すると
  // 「半分パース成功 + 半分捨てる」になりユーザの誤入力を見落とす。残余があれば
  // パースエラーを出す (DR-0007 Phase 4 後の残余チェック)。
  try
    @timespec.parse_timespec("2024-01-01Zgarbage", now=test_now) |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error for garbage after datetime")
  }
}

///|
test "parse_timespec: Reject with datetime (no error)" {
  // default_sign=Reject は「符号なし duration 単体」を弾く設定。datetime 単体は
  // duration を含まないので Reject の検査対象外、通常通り Absolute を返す
  // (= Reject は符号不明確な「ago/future どっち?」入力のガードであって、
  // 確定時刻入力は対象外)。
  debug_inspect(
    @timespec.parse_timespec(
      "2024-01-01T12:00:00Z",
      now=test_now,
      default_sign=Reject,
    ),
    content=(
      #|Some(Absolute(EpochTime(1704110400000), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: Reject with unsigned duration (error)" {
  // 符号なし "5m" を Reject mode で投げるとエラー。CLI 利用側が "ago/future の
  // 解釈をユーザに明示させたい" 場面で使う safety mode (= 符号曖昧入力を黙って
  // 解釈せず拒否することで誤利用を防ぐ)。
  try
    @timespec.parse_timespec("5m", now=test_now, default_sign=Reject) |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("expected error for unsigned duration with Reject")
  }
}

///|
test "parse_timespec: custom epoch (Snowflake)" {
  // epoch? パラメータで Unix 以外の基点 epoch を扱えること。Snowflake は
  // 2010-11-04T01:42:54Z を 0 とする ID 生成系で、Twitter 系 ID をそのまま
  // EpochTime として扱いたい場面で必要 (DR-0003 カスタム epoch)。
  // 結果の EpochTime は「Snowflake epoch 起点の ms」で表現される。
  let snowflake_epoch = @timespec.EpochTime(1288834974657L)
  // now = 1_700_000_000_000 (Unix ms) → Snowflake relative = 1_700_000_000_000 - 1_288_834_974_657 = 411_165_025_343
  let now_fn = fn() -> UInt64 { 1_700_000_000_000UL }
  let ts = @timespec.parse_timespec("0s", epoch=snowflake_epoch, now=now_fn)
  // epoch relative の now
  debug_inspect(
    ts,
    content=(
      #|Some(Relative(EpochTime(411165025343), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: default epoch is Unix" {
  // epoch? デフォルト値の確認: 省略時は Unix epoch (= EpochTime(0L)) と同等。
  // 明示 0L 指定と無指定で結果が同一であることで、デフォルトが暗黙に Unix 基準
  // であることを保証 (DR-0003 デフォルトは Unix epoch)。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let a = @timespec.parse_timespec(
    "5m",
    epoch=@timespec.EpochTime(0L),
    now=now_fn,
    default_sign=Minus,
  )
  let b = @timespec.parse_timespec("5m", now=now_fn, default_sign=Minus)
  assert_true(a == b)
}

///|
test "parse_timespec: custom epoch with datetime" {
  // datetime 入力でも custom epoch が一貫して適用されること: datetime 自体は
  // Unix 基準で計算 (1704110400000 ms) してから epoch 差分を引いて格納する
  // (= 内部表現はカスタム epoch 基準で統一、入力経路は問わない、DR-0003)。
  let snowflake_epoch = @timespec.EpochTime(1288834974657L)
  let now_fn = fn() -> UInt64 { 1_700_000_000_000UL }
  // datetime "2024-01-01T12:00:00Z" = 1704110400000 Unix ms
  // epoch relative = 1704110400000 - 1288834974657 = 415275425343
  let ts = @timespec.parse_timespec(
    "2024-01-01T12:00:00Z",
    epoch=snowflake_epoch,
    now=now_fn,
  )
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(415275425343), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: @ position equivalence" {
  // @ idempotency の包括テスト: 先頭 / 中間 / 末尾の 3 位置で結果同一を確認。
  // 中間 (1h@30m) も含めることで「duration トークン列の任意境界に @ を挿せる」
  // という規約の網羅性を担保 (DR-0008 @ 配置位置で意味を変えない)。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let a = @timespec.parse_timespec("@1h30m", now=now_fn, default_sign=Minus)
  let b = @timespec.parse_timespec("1h@30m", now=now_fn, default_sign=Minus)
  let c = @timespec.parse_timespec("1h30m@", now=now_fn, default_sign=Minus)
  assert_true(a == b)
  assert_true(b == c)
}

///|
test "parse_timespec: time-of-day reset @00:00" {
  // time-of-day (HH:MM) は now の「同日」の指定時刻を Absolute として返す
  // (= 今日の 00:00)。@00:00 は「今日の頭」というよくある CLI ユースケース、
  // now の日付部分を保持しつつ時刻だけ差し替える設計 (DR-0007 Phase 3)。
  let now_fn = fn() -> UInt64 { 1_000_000_000UL } // some now
  let ts = @timespec.parse_timespec("@00:00", now=now_fn, default_tz_offset=Utc)
  // should be today's midnight UTC
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(950400000), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: time-of-day @10:30" {
  // 任意時刻 (HH:MM) パターン: 00:00 以外でも正しく日付保持で時刻差し替えする。
  // 0 時起点との結果差 (= 10h30m 分の ms 差) で計算ロジックを実測検証。
  let now_fn = fn() -> UInt64 { 1_000_000_000UL }
  let ts = @timespec.parse_timespec("@10:30", now=now_fn, default_tz_offset=Utc)
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(988200000), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: time-of-day with duration @00:00+3h" {
  // time-of-day + 末尾 duration: HH:MM が anchor になり duration が加算オフセット
  // として作用する (= datetime + duration と同じ構造)。「今日の 0 時から 3 時間後」
  // を Absolute として保持 (DR-0007 Phase 3 + Phase 1 後置 duration の合成)。
  let now_fn = fn() -> UInt64 { 1_000_000_000UL }
  let ts = @timespec.parse_timespec(
    "@00:00+3h",
    now=now_fn,
    default_tz_offset=Utc,
    default_sign=Plus,
  )
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(961200000), Duration(10800000)))
    ),
  )
}

///|
test "parse_timespec: raw epoch ms (@DIGITS)" {
  // @ + 純粋数字 (単位なし) は raw epoch ms として解釈する specialized 経路。
  // log file の timestamp や DB の epoch カラムを直接渡せる利便性のため
  // (DR-0007 Phase 3.5, DR-0008 raw epoch ms 解釈)。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  // @1704110400000 → EpochTime(1704110400000) = 2024-01-01T12:00:00Z
  let ts = @timespec.parse_timespec("@1704110400000", now=now_fn)
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(1704110400000), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: raw epoch ms with duration" {
  // raw epoch ms 経路でも anchor + 後置 duration の合成が効くこと。
  // 「log 行の timestamp から 1 時間後」のようなユースケースを支える。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  // @1704110400000+1h → EpochTime(1704110400000 + 3600000)
  let ts = @timespec.parse_timespec("@1704110400000+1h", now=now_fn)
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(1704114000000), Duration(3600000)))
    ),
  )
}

///|
test "parse_timespec: @2026 is raw epoch not year" {
  // 重要な regression ガード: @2026 を「年 2026」と誤解釈しない。
  // 部分日付 (YYYY のみ) は DR-0009 で禁止しており、@ + 数字は常に raw epoch ms。
  // YYYY 解釈を許すと TZ オフセット +HH との構文曖昧性も発生するので一貫して
  // raw epoch ms 経路に倒す (DR-0008 raw epoch / DR-0009 部分日付禁止)。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let ts = @timespec.parse_timespec("@2026", now=now_fn)
  // 2026ms from epoch, NOT 2026-01-01
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(2026), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: @-100 negative raw epoch" {
  // raw epoch ms は負値も受け付ける (epoch 以前の時刻を扱える)。
  // EpochTime は Int64 内部表現で signed (= 歴史的 datetime や Snowflake 以前
  // 等で必要)。境界としては「@ + 符号付き数字」は raw epoch 経路を維持。
  let now_fn = fn() -> UInt64 { 1_000_000UL }
  let ts = @timespec.parse_timespec("@-100", now=now_fn)
  // 100ms before epoch
  debug_inspect(
    ts,
    content=(
      #|Some(Absolute(EpochTime(-100), Duration(0)))
    ),
  )
}

///|
test "parse_timespec: time-of-day single digit" {
  // HH:MM のゼロ詰めは任意 (1:0 == 01:00)。CLI 入力で人間が "1:0" と打っても
  // 同じ結果を期待するのが自然なので、zero-pad の有無で結果を変えない。
  let now_fn = fn() -> UInt64 { 1_000_000_000UL }
  let a = @timespec.parse_timespec("@1:0", now=now_fn, default_tz_offset=Utc)
  let b = @timespec.parse_timespec("@01:00", now=now_fn, default_tz_offset=Utc)
  assert_true(a == b)
}

///|
test "TimeSpec accessors" {
  // パターンマッチ不要のアクセサ網羅: Absolute/Relative 共通フィールドを
  // 個別関数で取れること、is_absolute での分岐、to_epoch_ms で raw ms 取得。
  // 利用側 (CLI etc.) でパターンマッチを書かずに済ませるための API surface。
  let ts : @timespec.TimeSpec = Absolute(
    @timespec.EpochTime(700000L),
    @timespec.Duration(-300000L),
  )
  debug_inspect(ts.epoch(), content="EpochTime(700000)")
  debug_inspect(ts.duration(), content="Duration(-300000)")
  assert_true(ts.is_absolute())
  debug_inspect(ts.to_epoch_ms(), content="700000")
}

///|
test "Duration::to_ms" {
  // newtype Duration(Int64) から raw ms を取り出すアクセサ。利用側が
  // pattern match なしで内部 ms 値にアクセスできることを保証する自明系テスト。
  debug_inspect(@timespec.Duration(5000L).to_ms(), content="5000")
}

///|
test "EpochTime::to_ms" {
  // 同上、EpochTime newtype 用の raw ms アクセサ。
  debug_inspect(@timespec.EpochTime(1000000L).to_ms(), content="1000000")
}

///|
test "parse_timespec: @ alone is Absolute(now)" {
  // 裸の "@" は「いまこの瞬間を Absolute で固定」したい意図。@ + 何もなし =
  // Absolute(now) として idempotent に解釈 (@ の固定化フラグだけが意味を持つ)。
  let ts = @timespec.parse_timespec("@", now=test_now)
  debug_inspect(ts, content="Some(Absolute(EpochTime(1000000), Duration(0)))")
}

///|
test "parse_timespec: now keyword is Relative(now)" {
  // "now" キーワードは Relative (= "現在" という方法を保持)。@ なしなので
  // 再シリアライズ時に "now" を復元できるよう Relative を選ぶ (DR-0006 結果 vs やり方)。
  let ts = @timespec.parse_timespec("now", now=test_now)
  debug_inspect(ts, content="Some(Relative(EpochTime(1000000), Duration(0)))")
}

///|
test "parse_timespec: @now is Absolute(now)" {
  // @now は @ で「結果を確定」させた現在時刻 = Absolute。"now" との対比で
  // @ の Absolute 化作用がキーワード入力にも一貫して適用されることを保証。
  let ts = @timespec.parse_timespec("@now", now=test_now)
  debug_inspect(ts, content="Some(Absolute(EpochTime(1000000), Duration(0)))")
}

///|
test "parse_timespec: NOW case insensitive" {
  // キーワード認識は大小文字不問。CLI 入力で大文字を打ってもエラーにせず
  // 同等扱い (= 利用者の体感に優しいデフォルト)。
  let ts = @timespec.parse_timespec("NOW", now=test_now)
  debug_inspect(ts, content="Some(Relative(EpochTime(1000000), Duration(0)))")
}

// 「無指定」を表すキーワード群: none / null / nil の 3 種を等価に許容。
// CLI 利用側で「片側無指定」(--since none --until 5m など) を表現したい場面
// に対応する。返り値は Some(TimeSpec) ではなく None (= 「指定なし」を
// 明示的に伝播)、エラーにはしない (= 入力として valid な「無指定」)。

///|
test "parse_timespec: none returns None" {
  let ts = @timespec.parse_timespec("none", now=test_now)
  debug_inspect(ts, content="None")
}

///|
test "parse_timespec: null returns None" {
  // null も none と等価。複数言語/慣習からの利用者を吸収する shorthand 群。
  let ts = @timespec.parse_timespec("null", now=test_now)
  debug_inspect(ts, content="None")
}

///|
test "parse_timespec: nil returns None" {
  // nil も同様 (Lisp/Ruby 系の慣習)。
  let ts = @timespec.parse_timespec("nil", now=test_now)
  debug_inspect(ts, content="None")
}

///|
test "parse_timespec: NONE case insensitive" {
  // 「無指定」キーワードも now と同様に大小文字不問。
  let ts = @timespec.parse_timespec("None", now=test_now)
  debug_inspect(ts, content="None")
}

///|
test "parse_range: none~5m" {
  // 範囲入力 (since~until 形式) で since が "none" のとき since=None になり、
  // until のみ有効な「過去 X 時間まで」を表現できる。CLI で「終端のみ指定したい」
  // ユースケースを支える。
  let r = @timespec.parse_range(
    input="none~5m",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(r.since, content="None")
  debug_inspect(
    r.until,
    content="Some(Relative(EpochTime(700000), Duration(-300000)))",
  )
}

///|
test "parse_timespec: empty string is error" {
  // 空文字列は「無指定」(none) とは別概念で、ParseError を出す。
  // 意図的な「無指定」は none / null / nil で表すべきで、空文字列を黙って
  // None として扱うと CLI のオプション渡し忘れを見逃すため (= 入力の意図を
  // 明示的に区別する設計)。エラーメッセージも実値で固定して regression 防止。
  try @timespec.parse_timespec("", now=test_now) |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"empty timespec string\")")
  } noraise {
    _ => fail("expected error for empty timespec")
  }
}

///|
test "parse_timespec: whitespace only is error" {
  // 空白のみも空文字列と同等の error 扱い (= trim 後に空の入力)。
  // 「うっかり空白だけ渡した」入力を空入力と区別せずに弾く。
  try @timespec.parse_timespec("   ", now=test_now) |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"empty timespec string\")")
  } noraise {
    _ => fail("expected error for whitespace-only timespec")
  }
}

///|
test "parse_range: 5m~none" {
  // 範囲入力の対称ケース: until 側のみ "none"。「since 以降ずっと」を表現できる。
  // 上の "none~5m" と合わせて、片側無指定の双方向対応を保証。
  let r = @timespec.parse_range(
    input="5m~none",
    now=range_test_now,
    default_sign=Minus,
  )
  debug_inspect(
    r.since,
    content="Some(Relative(EpochTime(700000), Duration(-300000)))",
  )
  debug_inspect(r.until, content="None")
}
