/// Returns the local timezone offset in minutes via JavaScript's
/// `Date.getTimezoneOffset()`. The sign is inverted because JS returns
/// the opposite convention (e.g. JST is -540 in JS, but +540 here).
///|
extern "js" fn local_tz_offset_minutes_ffi() -> Int =
  #| function() {
  #|   return -new Date().getTimezoneOffset();
  #| }
