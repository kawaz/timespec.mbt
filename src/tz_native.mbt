/// FFI binding to the C stub `local_tz_offset_minutes` (native_stub.c).
/// Returns the local timezone offset in minutes (e.g. 540 for JST).
///|
extern "C" fn local_tz_offset_minutes_ffi() -> Int = "local_tz_offset_minutes"
