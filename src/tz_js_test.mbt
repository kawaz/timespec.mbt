///| JS: local_tz_offset が有効な値を返すことを確認
/// JS ではプロセス内で TZ を変更できないため、値の妥当性のみ検証
test "js: local_tz_offset returns valid offset" {
  let tz = @timespec.local_tz_offset()
  match tz {
    Utc => () // UTC 環境
    Hour(h) => {
      // TZ オフセットは -12..+14 の範囲
      assert_true(h >= -12 && h <= 14)
    }
    Min(m) => {
      // 分単位オフセットは -720..+840 の範囲
      assert_true(m >= -720 && m <= 840)
    }
    Local => assert_true(false) // local_tz_offset は Local を返さない
  }
}
