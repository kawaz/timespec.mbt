///| C: setenv(name, value, overwrite)
#borrow(name, value)
extern "C" fn setenv(name : Bytes, value : Bytes, overwrite : Int) -> Int = "setenv"

///| C: tzset() — TZ 環境変数の変更を反映
extern "C" fn tzset() = "tzset"

///| ヘルパー: MoonBit 文字列を null 終端 UTF-8 Bytes に変換
fn to_c_string(s : String) -> Bytes {
  let buf = @buffer.new()
  buf.write_string_utf8(s.view())
  buf.write_byte(b'\x00')
  buf.to_bytes()
}

///| ヘルパー: TZ 環境変数を設定して tzset を呼ぶ
fn set_tz(tz : String) -> Unit {
  let _ = setenv(b"TZ\x00", to_c_string(tz), 1)
  tzset()
}

///|
test "native: TZ=Asia/Tokyo → Hour(9)" {
  set_tz("Asia/Tokyo")
  inspect(local_tz_offset(), content="Hour(9)")
}

///|
test "native: TZ=UTC → Utc" {
  set_tz("UTC")
  inspect(local_tz_offset(), content="Utc")
}

///|
test "native: TZ=America/New_York → Hour(-5) or Hour(-4)" {
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
  set_tz("Asia/Kolkata")
  inspect(local_tz_offset(), content="Min(330)")
}

///|
test "native: TZ=Pacific/Chatham → Min(765) or Min(825)" {
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
  set_tz("UTC")
  inspect(local_tz_offset(), content="Utc")
  set_tz("Asia/Tokyo")
  inspect(local_tz_offset(), content="Hour(9)")
  set_tz("UTC")
  inspect(local_tz_offset(), content="Utc")
}
