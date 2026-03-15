///| format_duration: Duration を符号付き duration 文字列にフォーマットする
fn format_duration(d : Duration) -> String {
  let ns = d.to_ns()
  let sign = if ns < 0L { "-" } else { "+" }
  let mut remain = if ns < 0L { -ns } else { ns }
  let buf = StringBuilder::new()
  buf.write_string(sign)
  if remain == 0L {
    buf.write_string("0s")
    return buf.to_string()
  }
  // weeks
  let weeks = remain / 604_800_000_000_000L
  remain = remain % 604_800_000_000_000L
  if weeks > 0L {
    buf.write_string(weeks.to_string())
    buf.write_char('w')
  }
  // days
  let days = remain / 86_400_000_000_000L
  remain = remain % 86_400_000_000_000L
  if days > 0L {
    buf.write_string(days.to_string())
    buf.write_char('d')
  }
  // hours
  let hours = remain / 3_600_000_000_000L
  remain = remain % 3_600_000_000_000L
  if hours > 0L {
    buf.write_string(hours.to_string())
    buf.write_char('h')
  }
  // minutes
  let minutes = remain / 60_000_000_000L
  remain = remain % 60_000_000_000L
  if minutes > 0L {
    buf.write_string(minutes.to_string())
    buf.write_char('m')
  }
  // seconds
  let seconds = remain / 1_000_000_000L
  remain = remain % 1_000_000_000L
  if seconds > 0L {
    buf.write_string(seconds.to_string())
    buf.write_char('s')
  }
  // milliseconds
  let millis = remain / 1_000_000L
  remain = remain % 1_000_000L
  if millis > 0L {
    buf.write_string(millis.to_string())
    buf.write_string("ms")
  }
  // microseconds
  let micros = remain / 1_000L
  remain = remain % 1_000L
  if micros > 0L {
    buf.write_string(micros.to_string())
    buf.write_string("us")
  }
  // nanoseconds
  if remain > 0L {
    buf.write_string(remain.to_string())
    buf.write_string("ns")
  }
  buf.to_string()
}

///| TimeSpec::to_cli_string: TimeSpec を CLI 文字列に再シリアライズする
pub fn TimeSpec::to_cli_string(self : TimeSpec) -> String {
  match self {
    Absolute(epoch_ms) =>
      try {
        epoch_to_iso8601(epoch_ms)
      } catch {
        _ => epoch_ms.to_string() // unreachable for non-Local TZ
      }
    Relative(_, duration) => format_duration(duration)
  }
}
