///| Duration: ミリ秒精度 or ミリ秒+サブミリ秒ナノ秒精度
pub(all) enum Duration {
  Ms(Int64)
  MsNs(Int64, Int)
} derive(Eq, Show)

///| TimeSpec: 絶対時刻 or 相対時刻（再シリアライズで意図を保存）
pub(all) enum TimeSpec {
  Absolute(Int64)
  Relative(Int64, Duration)
} derive(Eq, Show)

///| TimeRange: since/until のペア
pub(all) struct TimeRange {
  since : TimeSpec?
  until : TimeSpec?
} derive(Eq, Show)

///| ParseContext: parse_range のコンテキスト
pub(all) enum ParseContext {
  Since
  Until
  Range
} derive(Eq, Show)

///| Sign: 符号省略時のデフォルト解釈
pub(all) enum Sign {
  Minus
  Plus
  Reject
} derive(Eq, Show)

///| TzOffset: タイムゾーンオフセット
pub(all) enum TzOffset {
  Utc
  Local
  Hour(Int)
  Min(Int)
} derive(Eq, Show)

///| ParseError: パースエラー
pub(all) suberror ParseError {
  ParseError(String)
}

///|
pub impl Show for ParseError with output(self, logger) {
  match self {
    ParseError(msg) => logger.write_string(msg)
  }
}
