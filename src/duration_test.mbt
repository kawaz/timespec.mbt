///|
test "parse_duration: basic units" {
  // 単一/複合の短縮単位 (s/m/h/d/w) が ms に正しく換算されるか。
  // 単位の組合せ (1h30m45s 等) は左から積み上げで合算する。
  // ms 精度の Duration newtype の基本仕様 (DR-0006 Duration 命名)。
  debug_inspect(
    @timespec.parse_duration("5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1h30m"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("300s"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1h30m45s"),
    content=(
      #|Duration(5445000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2w"),
    content=(
      #|Duration(1209600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("3d"),
    content=(
      #|Duration(259200000)
    ),
  )
}

///|
test "parse_duration: decimal" {
  // 小数値も受け付け、ms 精度に丸める (1.5h = 90m = 5400000ms)。
  // 「1.5 時間」のような自然な指定を許すため、整数縛りにしない。
  debug_inspect(
    @timespec.parse_duration("1.5h"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("3.5s"),
    content=(
      #|Duration(3500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("0.5m"),
    content=(
      #|Duration(30000)
    ),
  )
}

///|
test "parse_duration: underscore" {
  // 数値内アンダースコアを桁区切りとして無視 (3_600_000ms = 3600000ms)。
  // 大きな ms 値を人間が読み書きしやすくする慣習 (多くの言語の数値リテラルと同じ)。
  // 小数部・複数 underscore (1_000.5_0) も同様に受け入れる。
  debug_inspect(
    @timespec.parse_duration("3_600_000ms"),
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000s"),
    content=(
      #|Duration(1000000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000.5s"),
    content=(
      #|Duration(1000500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1_000.5_0s"),
    content=(
      #|Duration(1000500)
    ),
  )
}

///|
test "parse_duration: ms unit" {
  // ms は最小精度単位 (Duration は Int64 ms newtype)。
  // これより細かい us/ns は別 test で reject されることを確認。
  debug_inspect(
    @timespec.parse_duration("100ms"),
    content=(
      #|Duration(100)
    ),
  )
}

///|
test "parse_duration: sub-ms units are errors" {
  // ms 未満の単位 (us / ns / μs) は明示的に reject。
  // 理由: Duration は ms 精度の Int64 で、sub-ms を受け入れると 0 に丸まる暗黙の
  // 精度損失が起きる。誤解を避けるため「黙って 0 に丸める」より「エラーで気づかせる」
  // を採用 (DR-0006 Duration 命名・精度方針)。
  try @timespec.parse_duration("500us") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for 500us")
  }
  try @timespec.parse_duration("1000ns") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for 1000ns")
  }
  try @timespec.parse_duration("500\u03BCs") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for 500\u03BCs")
  }
}

///|
test "parse_duration: duplicate merge" {
  // 同じ単位の重複出現 (1h ... 1h) も加算で合算する。
  // 「1h5m1h = 2h5m = 7500000ms」。順序や重複を許容することで、ユーザ生成入力に
  // 寛容にする (= strict な「同じ単位を 2 度書くな」を強制しない)。
  debug_inspect(
    @timespec.parse_duration("1h5m1h"),
    content=(
      #|Duration(7500000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Plus" {
  // default_sign=Plus (省略時 default): 符号なし入力は + として扱う。
  // 明示的な + / - はそのまま尊重。CLI で `--duration 5m` のような場合に「未来向き
  // の duration」として自然に扱える default。
  debug_inspect(
    @timespec.parse_duration("5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("+5m"),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m"),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Minus" {
  // default_sign=Minus: 符号なし入力を - として扱う (= 過去向き default)。
  // `--since 5m` のように「5 分前から」を符号なしで自然に表現したい CLI 想定。
  // 明示的な + / - は default を上書きする。
  debug_inspect(
    @timespec.parse_duration("5m", default_sign=Minus),
    content=(
      #|Duration(-300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("+5m", default_sign=Minus),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m", default_sign=Minus),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: sign with default_sign=Reject" {
  // default_sign=Reject: 符号なし入力をエラーにする (= 方向の暗黙仮定を禁止)。
  // 利用側が「方向は必ず明示してほしい」と要求する場面で使う厳格モード。
  // 符号なしはエラー
  try @timespec.parse_duration("5m", default_sign=Reject) |> ignore catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|ParseError("missing sign in duration: 5m")
        ),
      )
  } noraise {
    _ => fail("expected error for unsigned with default_sign=Reject")
  }
  // 符号ありはOK
  debug_inspect(
    @timespec.parse_duration("+5m", default_sign=Reject),
    content=(
      #|Duration(300000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("-5m", default_sign=Reject),
    content=(
      #|Duration(-300000)
    ),
  )
}

///|
test "parse_duration: expression with signs" {
  // 中置の +/- 演算子で複数 segment を加減算 (5s - 2m + 1h = 5 - 120 + 3600 = 3485 秒)。
  // 単一文字列で「補正値」の式表現を許可 (= 「1 時間ちょい前から 2 分前まで」を式で書ける)。
  debug_inspect(
    @timespec.parse_duration("5s-2m+1h"),
    content=(
      #|Duration(3485000)
    ),
  )
}

///|
test "parse_duration: whitespace" {
  // 任意位置の空白を無視 (segment 間 / 数値と単位の間 / 先頭末尾)。
  // CLI 引数で shell が空白を保つケース ("1 h 2 m") にも寛容にする。
  debug_inspect(
    @timespec.parse_duration("1h 2m"),
    content=(
      #|Duration(3720000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration(" 1h 2m "),
    content=(
      #|Duration(3720000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration(" 1 h 2 m "),
    content=(
      #|Duration(3720000)
    ),
  )
}

///|
test "parse_duration: errors" {
  // 受け付けない入力の境界確認:
  //   - 空文字 → 解釈不能でエラー
  //   - "5y" → 年単位は閏年/月差で ms 換算が一意に決まらないため非対応
  //   - "5" → 単位なし数値はエラー (ms と暗黙仮定しない、ユーザに明示を強制)
  // 空文字
  try @timespec.parse_duration("") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for empty input")
  }
  // 年は非対応
  try @timespec.parse_duration("5y") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for 5y")
  }
  // 数字のみ（ユニットなし）
  try @timespec.parse_duration("5") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for 5")
  }
}

///|
test "Duration constants" {
  // 公開定数の ms 値を固定 (リグレッション防止)。
  // millisecond=1, second=1000, minute=60_000, hour=3_600_000, day=86_400_000, week=604_800_000。
  // ユーザコードが Duration を組み立てる起点としてこの粒度を提供 (DR-0006)。
  debug_inspect(
    @timespec.millisecond,
    content=(
      #|Duration(1)
    ),
  )
  debug_inspect(
    @timespec.second,
    content=(
      #|Duration(1000)
    ),
  )
  debug_inspect(
    @timespec.minute,
    content=(
      #|Duration(60000)
    ),
  )
  debug_inspect(
    @timespec.hour,
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.day,
    content=(
      #|Duration(86400000)
    ),
  )
  debug_inspect(
    @timespec.week,
    content=(
      #|Duration(604800000)
    ),
  )
}

///|
test "Duration addition" {
  // Duration の `+` 演算子は ms 値の足し算。1h + 30m + 45s = 5445000ms。
  // scale(n) で倍化してから足せることも併せて確認。
  let d = @timespec.hour +
    @timespec.minute.scale(30L) +
    @timespec.second.scale(45L)
  debug_inspect(
    d,
    content=(
      #|Duration(5445000)
    ),
  )
}

///|
test "Duration subtraction" {
  // Duration の `-` は ms 差。1h - 30m = 1800000ms。
  let d = @timespec.hour - @timespec.minute.scale(30L)
  debug_inspect(
    d,
    content=(
      #|Duration(1800000)
    ),
  )
}

///|
test "Duration negation" {
  // 単項 `-` 演算子で符号反転 (= 過去/未来向きの方向を切り替える基本操作)。
  debug_inspect(
    -@timespec.hour,
    content=(
      #|Duration(-3600000)
    ),
  )
}

///|
test "Duration scale" {
  // scale(n) は整数倍。second.scale(90) = 90 秒 = 90000ms、hour.scale(24) = 1 日。
  // 演算子 `*` を使わず scale メソッドにする理由は newtype の意図保存
  // (= Duration * Duration を誤って書けないよう、明示的なスカラ倍 API に分離)。
  debug_inspect(
    @timespec.second.scale(90L),
    content=(
      #|Duration(90000)
    ),
  )
  debug_inspect(
    @timespec.hour.scale(24L),
    content=(
      #|Duration(86400000)
    ),
  )
}

///|
test "EpochTime + Duration" {
  // EpochTime (epoch からの ms) + Duration → 新しい EpochTime。
  // EpochTime と Duration を別 newtype に分けることで「時刻 + 時刻」のような
  // 無意味な演算を型レベルで防ぐ (DR-0006 EpochTime 命名)。
  let t = @timespec.EpochTime(1_000_000L)
  let d = @timespec.minute.scale(5L)
  debug_inspect(
    t.add_duration(d),
    content=(
      #|EpochTime(1300000)
    ),
  )
}

///|
test "parse_duration: long unit names" {
  // 短縮形 (s/m/h/d/w/ms) だけでなく英語の長形 (minutes/hour/days/week/
  // milliseconds/sec/min) も受け付ける。CLI 利用者が「3 minutes ago」のような
  // 自然言語風入力をしたくなる場面に対応する。
  debug_inspect(
    @timespec.parse_duration("3minutes"),
    content=(
      #|Duration(180000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1hour"),
    content=(
      #|Duration(3600000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2days"),
    content=(
      #|Duration(172800000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1week"),
    content=(
      #|Duration(604800000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("500milliseconds"),
    content=(
      #|Duration(500)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("30sec"),
    content=(
      #|Duration(30000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("5min"),
    content=(
      #|Duration(300000)
    ),
  )
}

///|
test "parse_duration: ago" {
  // "ago" 修飾子で末尾につけると全体の符号を反転 (= 過去向きに変換)。
  // 自然言語に近い表現 ("3 minutes ago") を + 符号付き duration から -180000ms に変換。
  // 後置 ago を採用したのは英語の語順に合わせるため (DR-0006 ago 修飾子)。
  debug_inspect(
    @timespec.parse_duration("3 minutes ago"),
    content=(
      #|Duration(-180000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("1 hour 30 minutes ago"),
    content=(
      #|Duration(-5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("5s ago"),
    content=(
      #|Duration(-5000)
    ),
  )
}

///|
test "parse_duration: ago negates group" {
  // "ago" の作用範囲は「直前の同符号 segment 群 (= 1 グループ)」。
  // 空白区切りの "1 hour 30 minutes" は 1 グループとしてまとめて反転される
  // (= -1h - 30m = -90m)。次の test 群で explicit + / - を挟むと境界が
  // 区切られることを確認する (= ago の作用範囲が変わる)。
  // グループ[1h+30m]を反転 → -90m = -5400000ms
  debug_inspect(
    @timespec.parse_duration("1 hour 30 minutes ago"),
    content=(
      #|Duration(-5400000)
    ),
  )
}

///|
test "parse_duration: ago with explicit plus" {
  // 明示的な `+` は新しいグループの開始を意味する。
  // "1 hour + 30 minutes ago" → グループ[1h], グループ[30m] (ago で反転)
  // → 1h + (-30m) = 30m = 1800000ms。
  // グループ[1h] + グループ[30m]を反転 → 1h + (-30m) = 30m = 1800000ms
  debug_inspect(
    @timespec.parse_duration("1 hour + 30 minutes ago"),
    content=(
      #|Duration(1800000)
    ),
  )
}

///|
test "parse_duration: ago with explicit minus" {
  // 明示的な `-` も新しいグループの開始。"1 hour - 30 minutes ago" →
  // グループ[1h], グループ[-30m] (ago で反転して +30m) → 1h + 30m = 90m。
  // (= ago は最後のグループの符号だけを flip する、それ以前のグループは触らない)
  // グループ[1h] - グループ[30m]を反転 → 1h - (-30m) = 90m = 5400000ms
  debug_inspect(
    @timespec.parse_duration("1 hour - 30 minutes ago"),
    content=(
      #|Duration(5400000)
    ),
  )
}

///|
test "parse_duration: ago then more segments" {
  // "ago" の後にもさらに segment を継ぐと、ago で flip 済みのグループはそのまま、
  // 後続グループは独立に加算される。3 ケースで explicit 符号有無を網羅:
  //   "30m ago 1h"  → ago で -30m に flip 後、暗黙 + で 1h 追加 → +30m
  //   "30m ago + 1h"→ 同上 (explicit +)
  //   "30m ago - 1h"→ 後続が -1h、-30m + (-1h) = -90m
  // グループ[30m]を反転, 新グループ[1h] → -30m + 1h = 30m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago 1h"),
    content=(
      #|Duration(1800000)
    ),
  )
  // グループ[30m]を反転, + グループ[1h] → -30m + 1h = 30m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago + 1h"),
    content=(
      #|Duration(1800000)
    ),
  )
  // グループ[30m]を反転, - グループ[1h] → -30m - 1h = -90m
  debug_inspect(
    @timespec.parse_duration("30 minutes ago - 1h"),
    content=(
      #|Duration(-5400000)
    ),
  )
}

///|
test "parse_duration: ago with leading sign" {
  // 先頭の符号と ago が両方ある場合は両者が乗算的に作用する。
  // "-5m ago" は「-5m を ago で反転」→ +5m。二重否定で意味は plus に戻る。
  // (= ago は単純な「最終結果を flip」ではなく、グループ単位で flip するため
  // 先頭符号と組み合わせて意味のある合成になる)
  // -5m ago: 先頭 - で negate=true, グループ[5m], ago反転 → group=-5m,
  // total=1*(-5m)=-5m, negate → +5m = 300000ms
  debug_inspect(
    @timespec.parse_duration("-5m ago"),
    content=(
      #|Duration(300000)
    ),
  )
}

///|
test "parse_duration: mixed long and short units" {
  // 同一入力内で long form (hour, days) と short form (m, h) を混在させても
  // 単位辞書は一つなので問題なく合算される (1hour + 30m = 5400000ms 等)。
  debug_inspect(
    @timespec.parse_duration("1hour 30m"),
    content=(
      #|Duration(5400000)
    ),
  )
  debug_inspect(
    @timespec.parse_duration("2 days 5h"),
    content=(
      #|Duration(190800000)
    ),
  )
}

///|
test "parse_duration: overflow detection" {
  // Int64 ms 表現の境界を超える入力を確実に検出する。境界は 2 種類:
  //   (a) 数値リテラル自体が Int64 を超える → "number too large"
  //   (b) 数値 × 単位倍率 が Int64 を超える → "duration overflow" (checked_mul)
  // それぞれを別ケースで踏み、エラーメッセージで区別可能なことも保証。
  // 静かに wrap して負値になると意味不明な期間が返るので、明示エラーが必須。
  // 非常に大きな数値で parse_number のオーバーフロー検出
  try @timespec.parse_duration("9999999999999999999ms") |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"number too large\")")
  } noraise {
    _ => fail("expected overflow error for 9999999999999999999ms")
  }
  // checked_mul でオーバーフロー検出 (15250284453 * 604800000 > Int64.MAX)
  try @timespec.parse_duration("15250284453w") |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"duration overflow\")")
  } noraise {
    _ => fail("expected overflow error for 15250284453w")
  }
  // checked_mul でオーバーフロー検出 (99999999999999h * 3600000 > Int64.MAX)
  try @timespec.parse_duration("99999999999999h") |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"duration overflow\")")
  } noraise {
    _ => fail("expected overflow error for 99999999999999h")
  }
}

///|
test "parse_duration: special inputs" {
  // 端のケース / 0 値 / 非常に小さい小数を体系的に確認:
  //   - 空文字列 / 単位なし数値はエラー (errors test と重複だが個別 message を固定)
  //   - 0.001s = 1ms (sub-ms 単位は禁止だが ms に丸まる小数は許可)
  //   - 0s / 0m / 0h は Duration(0) として有効 (= ゼロ期間も valid な値)
  // 空文字列 → エラー
  try @timespec.parse_duration("") |> ignore catch {
    e => debug_inspect(e, content="ParseError(\"empty duration string\")")
  } noraise {
    _ => fail("expected error for empty input")
  }
  // 数値のみ（単位なし） → エラー
  try @timespec.parse_duration("123") |> ignore catch {
    e =>
      debug_inspect(
        e,
        content="ParseError(\"missing unit after number in: 123\")",
      )
  } noraise {
    _ => fail("expected error for 123 (no unit)")
  }
  // 非常に小さい小数 → 1ms
  debug_inspect(@timespec.parse_duration("0.001s"), content="Duration(1)")
  // ゼロ値
  debug_inspect(@timespec.parse_duration("0s"), content="Duration(0)")
  debug_inspect(@timespec.parse_duration("0m"), content="Duration(0)")
  debug_inspect(@timespec.parse_duration("0h"), content="Duration(0)")
}
