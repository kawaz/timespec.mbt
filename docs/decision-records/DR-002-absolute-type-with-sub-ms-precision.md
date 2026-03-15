# DR-002: EpochTime 型の導入と sub-ms 精度の epoch

- **日付**: 2026-03-15
- **ステータス**: Accepted

> **注意**: DR-004 により EpochTime は `enum { Ms(Int64); MsNs(Int64, Int) }` から `struct EpochTime(Int64)` (newtype) に簡素化されました。

## 問題

`TimeSpec::Absolute(Int64)` では epoch が ms 精度しか持てない。
`@100ns` のような sub-ms 精度の絶対時刻を表現できない。

また `Absolute(Int64)` は Duration を持たないため、`@5m` がどのようなオフセットで計算されたかの情報が失われる。

## 決定

### EpochTime 型の導入

Duration と同構造だが「時点」を表す別型として `EpochTime` を導入する。

```moonbit
pub(all) enum EpochTime {
  Ms(Int64)          // epoch ms 精度
  MsNs(Int64, Int)   // epoch ms + sub-ms ns（0..999_999）
}
```

### TimeSpec の変更

```moonbit
pub(all) enum TimeSpec {
  Absolute(EpochTime, Duration)   // 絶対時刻 + 元のオフセット
  Relative(EpochTime, Duration)   // 相対時刻 + 元のオフセット
}
```

両バリアントが `(EpochTime, Duration)` を持つ。違いは再シリアライズの挙動:
- `TimeSpec::Absolute` → ISO 8601 タイムスタンプとして出力
- `TimeSpec::Relative` → 符号付き duration 文字列として出力

### 型の対応関係

| 型 | 意味 | 内部構造 |
|---|---|---|
| `Duration` | 期間（時間の長さ） | `Ms(Int64)` / `MsNs(Int64, Int)` |
| `EpochTime` | 時点（epoch からの経過） | `Ms(Int64)` / `MsNs(Int64, Int)` |

構造は同じだが意味が異なるため別型とする。

## 理由

1. **sub-ms 精度の epoch**: `@100ns` で epoch 自体が sub-ms 精度を持てる
2. **情報の保持**: `EpochTime` も Duration を持つことで、`@5m` のオフセット情報が保持される
3. **型安全**: 「時点」と「期間」を型レベルで区別。Duration + Duration は期間の加算、EpochTime + Duration は時点の移動

## 影響

- `TimeSpec::Absolute(Int64)` → `TimeSpec::Absolute(EpochTime, Duration)` に変更
- `TimeSpec::Relative(Int64, Duration)` → `TimeSpec::Relative(EpochTime, Duration)` に変更
- epoch_ms を使う箇所は `EpochTime` から取得するヘルパーが必要
- `to_cli_string` は `EpochTime` の epoch を使って ISO 8601 変換
