///| timespec_epoch: TimeSpec から epoch_ms を取得するヘルパー
fn timespec_epoch(ts : TimeSpec) -> Int64 {
  match ts {
    Absolute(ms) => ms
    Relative(ms, _) => ms
  }
}

///| is_absolute: TimeSpec が Absolute かどうか判定
fn is_absolute(ts : TimeSpec) -> Bool {
  match ts {
    Absolute(_) => true
    Relative(_, _) => false
  }
}

///| resolve_relative_with_anchor: anchor の epoch_ms を基準に Relative の epoch_ms を再計算する
///  両方 Relative の場合: duration の計算方向を s<=u を満たすように強制
///  Mixed (@ 絡み) の場合: 明示符号に従って計算
fn resolve_relative_with_anchor(
  ts : TimeSpec,
  anchor_epoch : Int64,
  force_direction : Int64 // +1 = forward, -1 = backward, 0 = 明示符号に従う
) -> TimeSpec {
  match ts {
    Absolute(_) => ts // 絶対は変更しない
    Relative(_, duration) => {
      let duration_ms = match duration {
        Ms(ms) => ms
        MsNs(ms, _) => ms
      }
      let new_epoch = if force_direction != 0L {
        // 両方 Relative: s<=u を満たす方向に強制
        let abs_ms = if duration_ms < 0L { -duration_ms } else { duration_ms }
        anchor_epoch + abs_ms * force_direction
      } else {
        // Mixed: 明示符号に従う
        anchor_epoch + duration_ms
      }
      Relative(new_epoch, duration)
    }
  }
}

///| parse_range: since~until の範囲をパースする
pub fn parse_range(
  input : String,
  context~ : ParseContext,
  default_sign~ : Sign = Plus,
  now~ : () -> UInt64 = @env.now,
  swap~ : Bool = false,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeRange raise ParseError {
  // 1. 入力を ~ で分割
  let s = input.view()
  let tilde_pos = find_tilde(s)
  let has_tilde = tilde_pos >= 0
  // ~ が2つ以上あるかチェック
  if has_tilde {
    let second_tilde = find_tilde_from(s, tilde_pos + 1)
    if second_tilde >= 0 {
      raise ParseError("multiple '~' found in range: " + input)
    }
  }
  let mut since : TimeSpec? = None
  let mut until : TimeSpec? = None
  if has_tilde {
    // 2パート: since_part ~ until_part
    let since_str = s[0:tilde_pos].to_string()
    let until_str = s[(tilde_pos + 1):s.length()].to_string()
    // 各パートをパース（空ならNone）
    // parse_timespec は内部で trim するので、ここでは trim 後の長さで空判定
    let since_ts : TimeSpec? = if since_str.trim().length() > 0 {
      Some(
        parse_timespec(since_str, default_sign~, now~, parse_datetime~),
      )
    } else {
      None
    }
    let until_ts : TimeSpec? = if until_str.trim().length() > 0 {
      Some(
        parse_timespec(until_str, default_sign~, now~, parse_datetime~),
      )
    } else {
      None
    }
    // アンカー解決
    match (since_ts, until_ts) {
      (Some(s_ts), Some(u_ts)) => {
        let resolved = resolve_anchor(s_ts, u_ts, context)
        since = Some(resolved.0)
        until = Some(resolved.1)
      }
      _ => {
        since = since_ts
        until = until_ts
      }
    }
  } else {
    // ~ なし: 単一パート
    let ts = parse_timespec(input, default_sign~, now~, parse_datetime~)
    match context {
      Since => since = Some(ts)
      Until => until = Some(ts)
      Range =>
        raise ParseError("range context requires '~' separator in: " + input)
    }
  }
  // swap: since > until なら入れ替え
  if swap {
    match (since, until) {
      (Some(s_ts), Some(u_ts)) =>
        if timespec_epoch(s_ts) > timespec_epoch(u_ts) {
          let tmp_since = since
          since = until
          until = tmp_since
        }
      _ => ()
    }
  }
  { since, until }
}

///| resolve_anchor: アンカー解決ロジック
fn resolve_anchor(
  since_ts : TimeSpec,
  until_ts : TimeSpec,
  context : ParseContext
) -> (TimeSpec, TimeSpec) {
  let s_abs = is_absolute(since_ts)
  let u_abs = is_absolute(until_ts)
  // 1. Mixed（片方だけ Absolute）→ 絶対側が anchor
  if s_abs && not(u_abs) {
    // since が anchor (Absolute)、until を since 基準で解決
    // @ 絡み → 明示符号に従う (force_direction=0)
    let new_until = resolve_relative_with_anchor(
      until_ts, timespec_epoch(since_ts), 0L,
    )
    return (since_ts, new_until)
  }
  if u_abs && not(s_abs) {
    // until が anchor (Absolute)、since を until 基準で解決
    // @ 絡み → 明示符号に従う (force_direction=0)
    let new_since = resolve_relative_with_anchor(
      since_ts, timespec_epoch(until_ts), 0L,
    )
    return (new_since, until_ts)
  }
  // 2. 同種の場合
  match context {
    Since => {
      // since が anchor、until を since 基準で解決
      // 両方 Relative or 両方 Absolute
      if s_abs && u_abs {
        // 両方 Absolute → 独立（各自 now 基準で既に解決済み）
        (since_ts, until_ts)
      } else {
        // 両方 Relative → until を since 基準で forward 解決
        let new_until = resolve_relative_with_anchor(
          until_ts, timespec_epoch(since_ts), 1L,
        )
        (since_ts, new_until)
      }
    }
    Until => {
      // until が anchor、since を until 基準で解決
      if s_abs && u_abs {
        (since_ts, until_ts)
      } else {
        // 両方 Relative → since を until 基準で backward 解決
        let new_since = resolve_relative_with_anchor(
          since_ts, timespec_epoch(until_ts), -1L,
        )
        (new_since, until_ts)
      }
    }
    Range => {
      // anchor なし → 各自独立に now 基準で解決（既にパース済み）
      (since_ts, until_ts)
    }
  }
}

///| find_tilde: 文字列内の最初の ~ の位置を返す（なければ -1）
fn find_tilde(s : StringView) -> Int {
  find_tilde_from(s, 0)
}

///| find_tilde_from: 指定位置から最初の ~ の位置を返す（なければ -1）
fn find_tilde_from(s : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < s.length() {
    match s.get_char(pos) {
      Some('~') => return pos
      _ => pos += 1
    }
  }
  -1
}
