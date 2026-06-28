// White-box tests for Duration internals

///|
test "checked_mul: -1 * Int64::min_value should raise ParseError, not WASM trap" {
  // -1 * Int64::min_value は数学的に Int64 範囲外 (|min| = max+1)。素朴な
  // "掛けてから result / a で逆算検証" 方式だと min_value / -1 自体が overflow し、
  // WASM では division trap でプロセスが落ちる。ParseError として観測可能な失敗に
  // 抑える必要がある (DR-0006 — overflow は raise で握り、trap させない)。
  let min_val = -9223372036854775807L - 1L // Int64::min_value
  try checked_mul(-1L, min_val) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for -1 * min_value")
  }
}

///|
test "checked_mul: Int64::min_value * -1 should raise ParseError, not WASM trap" {
  // 引数順序を逆にした対称ケース。実装が a, b のどちら側で逆算するかに依らず
  // trap を起こさず ParseError に倒すことを保証する (片側だけ守ると順序依存の
  // bug を残しやすい)。
  let min_val = -9223372036854775807L - 1L
  try checked_mul(min_val, -1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for min_value * -1")
  }
}

///|
test "checked_mul: normal overflow detection still works" {
  // min_value trap 回避策を入れた後でも、通常の overflow (= max * 2) が依然
  // ParseError として検出されることの回帰確認。trap 回避を special-case で
  // 入れたせいで普通の overflow を見逃すと本末転倒。
  try checked_mul(9223372036854775807L, 2L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for overflow")
  }
}

///|
test "checked_mul: zero cases" {
  // 0 が絡むケースは数学的に常に 0 だが、実装が「逆算検証」で 0 除算を踏むと
  // ここで trap する。0 * min_value / min_value * 0 の両側で 0 を返すことを
  // 確認 (= 逆算前に 0 分岐を持っているかの境界テスト)。
  let v1 = checked_mul(0L, -9223372036854775807L - 1L)
  assert_eq(v1, 0L)
  let v2 = checked_mul(-9223372036854775807L - 1L, 0L)
  assert_eq(v2, 0L)
}

///|
test "checked_mul: normal multiplication" {
  // sanity: overflow ガードが正の常用ケースで偽陽性を出さないこと。
  let v = checked_mul(3L, 7L)
  assert_eq(v, 21L)
}

///|
test "checked_mul: negative normal multiplication" {
  // sanity: 符号混在の常用ケース (= 負 * 正) でも偽陽性 / trap が無いこと。
  // -1 * min_value 経路の special-case が一般の負数ケースを巻き込んで誤検出
  // しないことの回帰確認も兼ねる。
  let v = checked_mul(-3L, 7L)
  assert_eq(v, -21L)
}

///|
test "checked_add: no trap on Int64 boundary values" {
  // checked_add は division を使わず符号ビット判定 (= 同符号同士の加算で結果の
  // 符号が反転していれば overflow) で検知するため、checked_mul のような WASM
  // trap リスクは構造上無い。境界 3 ケース (= 負側 overflow / 正側 overflow /
  // 反対符号で overflow しない) で「overflow は ParseError、合法な極端値は
  // 通る」を担保する。
  let min_val = -9223372036854775807L - 1L
  let max_val = 9223372036854775807L
  // min + 負: 両方負で結果が正に wrap = overflow 検知すべき。
  try checked_add(min_val, -1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected overflow error for min + -1")
  }
  // max + 正: 両方正で結果が負に wrap = overflow 検知すべき。
  try checked_add(max_val, 1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected overflow error for max + 1")
  }
  // 反対符号同士は数学的に overflow し得ない (= |a+b| <= max(|a|,|b|))。
  // min + max = -1 が通る = 過剰検知を入れていないことの裏取り。
  let v3 = checked_add(min_val, max_val)
  assert_eq(v3, -1L)
}
