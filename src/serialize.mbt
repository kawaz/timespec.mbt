/// Formats a `Duration` as a signed human-readable string (e.g. `"+1h30m"`, `"-5s"`).
///
/// Uses the largest possible units (weeks, days, hours, minutes, seconds, ms)
/// and omits zero-valued components. Zero duration is formatted as `"+0s"`.
///|
fn format_duration(d : Duration) -> String {
  let ms = d.0
  let sign = if ms < 0L { "-" } else { "+" }
  let mut remain = if ms < 0L { -ms } else { ms }
  let buf = StringBuilder::new()
  buf.write_string(sign)
  if remain == 0L {
    buf.write_string("0s")
    return buf.to_string()
  }
  // weeks
  let weeks = remain / week.0
  remain = remain % week.0
  if weeks > 0L {
    buf.write_string(weeks.to_string())
    buf.write_char('w')
  }
  // days
  let days = remain / day.0
  remain = remain % day.0
  if days > 0L {
    buf.write_string(days.to_string())
    buf.write_char('d')
  }
  // hours
  let hours = remain / hour.0
  remain = remain % hour.0
  if hours > 0L {
    buf.write_string(hours.to_string())
    buf.write_char('h')
  }
  // minutes
  let minutes = remain / minute.0
  remain = remain % minute.0
  if minutes > 0L {
    buf.write_string(minutes.to_string())
    buf.write_char('m')
  }
  // seconds
  let seconds = remain / second.0
  remain = remain % second.0
  if seconds > 0L {
    buf.write_string(seconds.to_string())
    buf.write_char('s')
  }
  // milliseconds
  if remain > 0L {
    buf.write_string(remain.to_string())
    buf.write_string("ms")
  }
  buf.to_string()
}

/// Re-serializes a `TimeSpec` into a CLI-friendly string.
///
/// - `Absolute` → ISO 8601 UTC datetime (e.g. `"2025-03-15T00:56:14Z"`).
/// - `Relative` → signed duration string (e.g. `"-8m"`, `"+1h30m"`).
///
/// Parameters:
///
/// * `self` : The `TimeSpec` to serialize.
/// * `epoch~` : Epoch offset to add back to absolute values. Defaults to zero.
///
/// Returns a string suitable for passing to `--since` or `--until` CLI arguments.
///|
pub fn TimeSpec::to_cli_string(
  self : TimeSpec,
  epoch~ : EpochTime = EpochTime(0L)
) -> String {
  match self {
    Absolute(epoch_time, _) => {
      let ms = epoch_time.0 + epoch.0
      epoch_to_iso8601(ms)
    }
    Relative(_, duration) => format_duration(duration)
  }
}
