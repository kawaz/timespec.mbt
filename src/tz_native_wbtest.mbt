///|
/// C: setenv(name, value, overwrite)
#borrow(name, value)
extern "C" fn setenv(name : Bytes, value : Bytes, overwrite : Int) -> Int = "setenv"

///|
/// C: tzset() — TZ 環境変数の変更を反映
extern "C" fn tzset() = "tzset"

///|
/// ヘルパー: MoonBit 文字列を null 終端 UTF-8 Bytes に変換
fn to_c_string(s : String) -> Bytes {
  let buf = Buffer()
  buf.write_string_utf8(s.view())
  buf.write_byte(b'\x00')
  buf.to_bytes()
}

///|
/// ヘルパー: TZ 環境変数を設定して tzset を呼ぶ
fn set_tz(tz : String) -> Unit {
  let _ = setenv(b"TZ\x00", to_c_string(tz), 1)
  tzset()
}

///|
test "native: TZ=Asia/Tokyo → Hour(9)" {
  // 整数時間オフセット (+09:00) のケース。Hour variant でコンパクトに
  // 表現されることを確認 (= 分単位 Min(540) でなく Hour(9) を採る正規化規約)。
  // FFI 経由で C 標準ライブラリの localtime/tzset 結果を読む経路の sanity check
  // (DR-0006 FFI)。
  set_tz("Asia/Tokyo")
  debug_inspect(local_tz_offset(), content="Hour(9)")
}

///|
test "native: TZ=UTC → Utc" {
  // オフセット 0 は Hour(0) でなく専用 Utc variant に正規化される。
  // 「UTC である」という意味論を型レベルで保持するため (= 数値 0 と区別)。
  set_tz("UTC")
  debug_inspect(local_tz_offset(), content="Utc")
}

///|
test "native: TZ=America/New_York → Hour(-5) or Hour(-4)" {
  // 負オフセット + DST 切替がある TZ の代表例。EST=-5, EDT=-4 のどちらが返るかは
  // テスト実行時刻 (季節) に依存するため、固定値 inspect でなく match で
  // 両方許容する。FFI が現在時刻の DST 状態を正しく反映していることの確認。
  set_tz("America/New_York")
  let tz = local_tz_offset()
  // EST=-5, EDT=-4（DST 依存）
  match tz {
    Hour(h) => assert_true(h == -5 || h == -4)
    _ => assert_true(false)
  }
}

///|
test "native: TZ=Asia/Kolkata → Min(330)" {
  // 整数時間で表せない 30 分オフセット (+05:30) のケース。Hour variant に
  // 落とせないので Min(330) に正規化される (= 分単位で必要な分だけ Min を使う
  // 二段階正規化の境界例)。
  set_tz("Asia/Kolkata")
  debug_inspect(local_tz_offset(), content="Min(330)")
}

///|
test "native: TZ=Pacific/Chatham → Min(765) or Min(825)" {
  // 45 分オフセット (+12:45 / DST 時 +13:45) という極端例。Min variant が
  // 15 分単位の半端オフセットまで扱えることと、DST 切替で 60 分動く挙動の確認。
  set_tz("Pacific/Chatham")
  let tz = local_tz_offset()
  // +12:45 (標準) or +13:45 (DST)
  match tz {
    Min(m) => assert_true(m == 765 || m == 825)
    _ => assert_true(false)
  }
}

///|
test "native: TZ 変更が即座に反映される" {
  // tzset() 呼出後に local_tz_offset() が新しい TZ を即座に反映することの確認。
  // C 標準ライブラリは tzset を呼ばないと TZ 変更が反映されないため、
  // set_tz ヘルパー内で必ず tzset を呼ぶ実装になっているかの実機検証
  // (= プロセス内で TZ を動的に切替えるテストパターン全体の前提条件)。
  set_tz("UTC")
  debug_inspect(local_tz_offset(), content="Utc")
  set_tz("Asia/Tokyo")
  debug_inspect(local_tz_offset(), content="Hour(9)")
  set_tz("UTC")
  debug_inspect(local_tz_offset(), content="Utc")
}
