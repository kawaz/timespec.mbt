///|
test "parse_tz_offset: empty and UTC/GMT variants" {
  // 空文字 / "Z" / "UTC" / "GMT" は全て UTC=0 を意味する標準表記。
  // 大小文字非依存 ("gmt" も OK) で受け、内部は単一の Utc バリアントに正規化
  // (= Hour(0) と Utc の表現重複を許容しつつ、文字列入力経路では Utc に倒す)。
  debug_inspect(
    @timespec.parse_tz_offset(""),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Z"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("UTC"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("gmt"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: hour only" {
  // 時単位のみの入力 ("9" / "+9" / "+09" / "-5") は Hour バリアントに格納
  // (= 分情報がないので Min ではない)。先頭符号は省略時 +、明示 + / - は
  // そのまま符号となる。0 埋め有無は等価 ("9" == "+09")。
  debug_inspect(
    @timespec.parse_tz_offset("9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+09"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-5"),
    content=(
      #|Hour(-5)
    ),
  )
}

///|
test "parse_tz_offset: HHMM and HH:MM" {
  // HHMM / HH:MM の両形式を受ける (RFC 3339 互換 + ISO 8601 basic 互換)。
  // 分が 0 なら Hour に縮約 ("+0900" → Hour(9))、非 0 なら Min(全分) に
  // 格納 ("+0530" → Min(330) = 5*60+30)。表現の縮約は DR-0006 の方針。
  debug_inspect(
    @timespec.parse_tz_offset("+0900"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+09:00"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+0530"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+05:30"),
    content=(
      #|Min(330)
    ),
  )
}

///|
test "parse_tz_offset: duration format" {
  // duration 形式 (5h30m / -5h / 9h) も TZ オフセットとして受ける。
  // parse_duration と同じ字句を再利用することで「±9h」と「+09:00」を
  // 統一的に扱えるようにする狙い (= ユーザの直感的入力を許容)。
  // 分の有無で Hour / Min を選択する縮約は HHMM と同じ。
  debug_inspect(
    @timespec.parse_tz_offset("5h30m"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+5h30m"),
    content=(
      #|Min(330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-5h"),
    content=(
      #|Hour(-5)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("9h"),
    content=(
      #|Hour(9)
    ),
  )
}

///|
test "parse_tz_offset: zero offset" {
  // 「0 を意図した入力」("0" / "+0" / "-00:00") は符号有無や形式に関わらず
  // 全て Utc に正規化する (= Hour(0) でも Min(0) でもなく Utc)。理由: ±0 に
  // 符号意味はなく、再シリアライズ時に "Z" / "UTC" 経路へ収束させたい。
  debug_inspect(
    @timespec.parse_tz_offset("0"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+0"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-00:00"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: negative minutes" {
  // 負の符号は全体に効く (= -5:30 は -(5h30m) = -330 分)。「時だけ負、分は正」
  // のような部分符号は不可。HH:MM / HHMM どちらの記法でも同じ。
  debug_inspect(
    @timespec.parse_tz_offset("-5:30"),
    content=(
      #|Min(-330)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-0530"),
    content=(
      #|Min(-330)
    ),
  )
}

///|
test "parse_tz_offset: lowercase z" {
  // "Z" の小文字も受ける。RFC 3339 自体は大文字 Z のみだが、CLI 入力の
  // 寛容性を優先 (= "z" を弾く理由がない)。
  debug_inspect(
    @timespec.parse_tz_offset("z"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: case-insensitive UTC" {
  // "UTC" の大小文字混在 ("utc" / "Utc") も同等に受ける。Z と同じ寛容性方針。
  debug_inspect(
    @timespec.parse_tz_offset("utc"),
    content=(
      #|Utc
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Utc"),
    content=(
      #|Utc
    ),
  )
}

///|
test "parse_tz_offset: GMT+offset" {
  // "GMT" / "UTC" を prefix とした合成形式 ("GMT+9" / "UTC+5:30" 等) を受ける。
  // よく使われる表記揺れ (= POSIX TZ や口語的表現) を吸収するための寛容化。
  // prefix を剥がした後ろは通常の符号付き表記と同じ解釈ルール。
  debug_inspect(
    @timespec.parse_tz_offset("GMT+9"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT+0900"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT+09:00"),
    content=(
      #|Hour(9)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("GMT-5"),
    content=(
      #|Hour(-5)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("UTC+5:30"),
    content=(
      #|Min(330)
    ),
  )
}

///|
test "parse_tz_offset: trailing garbage error" {
  // 妥当な接頭辞 ("+09:00") の後ろに余計な文字 ("abc") が続く場合は error。
  // 「先頭一致で読めるだけ読んで残りを無視」ではなく「全消費」を要求する
  // (= silent truncation で意図しない値を返さない安全側設計)。
  try @timespec.parse_tz_offset("+09:00abc") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for trailing garbage")
  }
}

///|
test "parse_tz_offset: seconds not valid as tz" {
  // 秒単位は TZ オフセットとして無効。理由: 実世界の TZ は分粒度までしか
  // 使われない (RFC 3339 も HH:MM)、parse_duration とは粒度ポリシーが異なる。
  try @timespec.parse_tz_offset("30s") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for seconds")
  }
}

///|
test "parse_tz_offset: local" {
  // 文字列 "local" は Local バリアントを返す (= 実行時に local_tz_offset() で
  // 解決する遅延評価マーカー)。大小文字非依存。"Z" / "UTC" 等の即値と異なり、
  // Local は意図の保存 (= 「ユーザは local を指定した」) を持つ。
  debug_inspect(
    @timespec.parse_tz_offset("local"),
    content=(
      #|Local
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("LOCAL"),
    content=(
      #|Local
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("Local"),
    content=(
      #|Local
    ),
  )
}

///|
test "local_tz_offset returns valid TzOffset" {
  // local_tz_offset() は OS から解決済みの実値を返すため、Local 自身を
  // 返してはいけない (= Local は「解決待ち」マーカーで、解決後の値が
  // また Local だと循環参照になる)。Utc / Hour / Min のいずれかになる。
  let tz = @timespec.local_tz_offset()
  match tz {
    Utc => ()
    Hour(_) => ()
    Min(_) => ()
    Local => assert_true(false)
  }
}

///|
test "parse_tz_offset: boundary values" {
  // 範囲チェックの内側端。±24h (= ±1440 分) を受容上限とする (DR-0005)。
  // 理由: 実世界の全 TZ は UTC-12〜UTC+14 に収まり、±24h はそれを十分カバー
  // しつつ「±25h は明らかな入力ミス」と区別できる切れ目。+14 / -12 は実存 TZ
  // の最大値、±24 はちょうど境界 (= ここまで OK、+25 から NG)。
  debug_inspect(
    @timespec.parse_tz_offset("+14"),
    content=(
      #|Hour(14)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-12"),
    content=(
      #|Hour(-12)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("+24"),
    content=(
      #|Hour(24)
    ),
  )
  debug_inspect(
    @timespec.parse_tz_offset("-24"),
    content=(
      #|Hour(-24)
    ),
  )
}

///|
test "parse_tz_offset: out of range error" {
  // 範囲チェックの外側端。±24h を超えると error (DR-0005)。+25 / -25 が
  // ちょうど境界の一つ外、+99 は明らかな範囲外 (= 「入力ミス検出」目的の
  // 上限が機能していることを示すサンプル)。
  try @timespec.parse_tz_offset("+25") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for +25")
  }
  try @timespec.parse_tz_offset("-25") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for -25")
  }
  try @timespec.parse_tz_offset("+99") |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected error for +99")
  }
}
