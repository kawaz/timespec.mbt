// White-box tests for Duration internals

///|
test "checked_mul: -1 * Int64::min_value should raise ParseError, not WASM trap" {
  // Int64::min_value = -9223372036854775808
  // -1 * Int64::min_value overflows, and then result / a = Int64::min_value / -1
  // causes a WASM trap (integer overflow in division) instead of raising ParseError.
  let min_val = -9223372036854775807L - 1L // Int64::min_value
  let result = try? checked_mul(-1L, min_val)
  assert_true(result is Err(_))
}

///|
test "checked_mul: Int64::min_value * -1 should raise ParseError, not WASM trap" {
  let min_val = -9223372036854775807L - 1L
  let result = try? checked_mul(min_val, -1L)
  assert_true(result is Err(_))
}

///|
test "checked_mul: normal overflow detection still works" {
  // Large values that overflow
  let result = try? checked_mul(9223372036854775807L, 2L)
  assert_true(result is Err(_))
}

///|
test "checked_mul: zero cases" {
  let r1 = try? checked_mul(0L, -9223372036854775807L - 1L)
  guard r1 is Ok(v1) else { fail("expected Ok") }
  assert_eq(v1, 0L)
  let r2 = try? checked_mul(-9223372036854775807L - 1L, 0L)
  guard r2 is Ok(v2) else { fail("expected Ok") }
  assert_eq(v2, 0L)
}

///|
test "checked_mul: normal multiplication" {
  let r = try? checked_mul(3L, 7L)
  guard r is Ok(v) else { fail("expected Ok") }
  assert_eq(v, 21L)
}

///|
test "checked_mul: negative normal multiplication" {
  let r = try? checked_mul(-3L, 7L)
  guard r is Ok(v) else { fail("expected Ok") }
  assert_eq(v, -21L)
}

///|
test "checked_add: no trap on Int64 boundary values" {
  // checked_add uses sign-bit detection, no division, so should be safe
  let min_val = -9223372036854775807L - 1L
  let max_val = 9223372036854775807L
  // min + negative overflows (both negative, result wraps to positive)
  let r1 = try? checked_add(min_val, -1L)
  assert_true(r1 is Err(_))
  // max + positive overflows (both positive, result wraps to negative)
  let r2 = try? checked_add(max_val, 1L)
  assert_true(r2 is Err(_))
  // min + max does not overflow
  let r3 = try? checked_add(min_val, max_val)
  guard r3 is Ok(v3) else { fail("expected Ok") }
  assert_eq(v3, -1L)
}
