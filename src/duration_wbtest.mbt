// White-box tests for Duration internals

///|
test "checked_mul: -1 * Int64::min_value should raise ParseError, not WASM trap" {
  // Int64::min_value = -9223372036854775808
  // -1 * Int64::min_value overflows, and then result / a = Int64::min_value / -1
  // causes a WASM trap (integer overflow in division) instead of raising ParseError.
  let min_val = -9223372036854775807L - 1L // Int64::min_value
  try checked_mul(-1L, min_val) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for -1 * min_value")
  }
}

///|
test "checked_mul: Int64::min_value * -1 should raise ParseError, not WASM trap" {
  let min_val = -9223372036854775807L - 1L
  try checked_mul(min_val, -1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for min_value * -1")
  }
}

///|
test "checked_mul: normal overflow detection still works" {
  // Large values that overflow
  try checked_mul(9223372036854775807L, 2L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected ParseError for overflow")
  }
}

///|
test "checked_mul: zero cases" {
  let v1 = checked_mul(0L, -9223372036854775807L - 1L)
  assert_eq(v1, 0L)
  let v2 = checked_mul(-9223372036854775807L - 1L, 0L)
  assert_eq(v2, 0L)
}

///|
test "checked_mul: normal multiplication" {
  let v = checked_mul(3L, 7L)
  assert_eq(v, 21L)
}

///|
test "checked_mul: negative normal multiplication" {
  let v = checked_mul(-3L, 7L)
  assert_eq(v, -21L)
}

///|
test "checked_add: no trap on Int64 boundary values" {
  // checked_add uses sign-bit detection, no division, so should be safe
  let min_val = -9223372036854775807L - 1L
  let max_val = 9223372036854775807L
  // min + negative overflows (both negative, result wraps to positive)
  try checked_add(min_val, -1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected overflow error for min + -1")
  }
  // max + positive overflows (both positive, result wraps to negative)
  try checked_add(max_val, 1L) |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected overflow error for max + 1")
  }
  // min + max does not overflow
  let v3 = checked_add(min_val, max_val)
  assert_eq(v3, -1L)
}
