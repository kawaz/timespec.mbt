# DR-003: カスタム epoch パラメータ

- **日付**: 2026-03-15
- **ステータス**: Accepted

## 背景

EpochTime は「ある基準点（epoch）からの経過時間」を表す。デフォルトは Unix Epoch（1970-01-01T00:00:00Z）だが、システムによって異なる epoch を使う場合がある:

- **Unix Epoch**: 1970-01-01T00:00:00Z（デフォルト）
- **Snowflake Epoch**: 2010-11-04T01:42:54.657Z（Twitter の ID 生成）
- **Performance API**: ページロード時点
- **macOS CFAbsoluteTime**: 2001-01-01T00:00:00Z

## 決定

`parse_timespec` と `parse_range` に `epoch~` パラメータを追加する。

```moonbit
pub fn parse_timespec(
  input : String,
  epoch~ : EpochTime = EpochTime(0L),  // Unix Epoch
  ...
) -> TimeSpec raise ParseError

pub fn parse_range(
  input : String,
  epoch~ : EpochTime = EpochTime(0L),
  ...
) -> TimeRange raise ParseError
```

### 動作

- `now~()` は常に Unix epoch ms (UInt64) を返す
- `epoch~` は EpochTime の基準点を Unix epoch ms からのオフセットで指定
- 内部計算: `now_relative = now_unix_ms - epoch_ms`
- EpochTime の値は指定された epoch からの相対値として格納
- ISO 8601 への変換時: `unix_ms = epoch_time_ms + epoch_ms` で Unix epoch に戻してから変換

### 例

```
// Unix Epoch（デフォルト）
parse_timespec("5m")  // EpochTime は Unix epoch ms

// Snowflake Epoch
let snowflake_epoch = EpochTime(1288834974657L)
parse_timespec("5m", epoch~=snowflake_epoch)
// now は Unix epoch ms → snowflake epoch ms に変換してから計算
```

## 理由

- EpochTime の概念的な正確さ: epoch は差し替え可能であるべき
- Snowflake 等のカスタム epoch システムとの互換性
- デフォルトが Unix Epoch なので既存コードへの影響なし
