///|
/// JS: local_tz_offset が有効な値を返すことを確認
/// JS ではプロセス内で TZ を変更できないため、値の妥当性のみ検証
test "js: local_tz_offset returns valid offset" {
  // JS 経路の local_tz_offset は Date.getTimezoneOffset() を呼んで符号を反転
  // した結果を返す (= getTimezoneOffset は UTC - local の分数を返すため、
  // local - UTC に直すには符号反転が必要)。JS では Node.js process 内で TZ を
  // 動的変更できないため、ここでは「返り値が地球上で実在する TZ オフセット
  // 範囲に収まっているか」と「local_tz_offset は Local バリアント
  // (= sentinel) を返さない (実体のある offset に解決済み)」のみ検証する。
  // 関連: DR-0006 (FFI 設計, local_tz_offset の JS / native 両対応)。
  let tz = @timespec.local_tz_offset()
  match tz {
    Utc => () // UTC 環境 (getTimezoneOffset() == 0)
    Hour(h) =>
      // 実在 TZ の hour 表現は -12 (Baker Island 等) ～ +14 (Kiribati Line Islands)
      assert_true(h >= -12 && h <= 14)
    Min(m) =>
      // 分単位は ±14h を分換算した -720..+840 (= +14h は +840 分)
      assert_true(m >= -720 && m <= 840)
    Local =>
      // Local は「未解決の意図」を表す sentinel。local_tz_offset は実体に
      // 解決した値を返すため、Local が返ったら実装 bug
      assert_true(false)
  }
}
