/// Returns UTC offset (0) as a fallback for WASM/WASI targets.
/// WASI does not provide a timezone API, so this always returns 0.
///|
fn local_tz_offset_minutes_ffi() -> Int {
  0
}
