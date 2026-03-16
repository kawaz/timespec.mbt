# DR-006: 設計決定まとめ

- **日付**: 2026-03-16
- **ステータス**: Accepted

## 1. parse_range の2引数方式

`since~` と `until~` を個別に受け取る。`input~` で `~` 形式も対応。
アンカー解決は Mixed ルール（片方 Absolute なら anchor）のみ。

## 2. ago 修飾子のグループレベル反転

`ago` は明示的 `+`/`-` で区切られたグループを反転し、次のグループを開始。
部分式の合成可能性を保証する。

## 3. EpochTime の命名

`Duration`（期間）と対をなす「時点」の型。epoch からの経過時間を表す。
`Absolute` → `Instant` → `Epoch` → `EpochTime` の変遷を経て決定。

## 4. Duration 定数と演算子

`millisecond`〜`week` 定数、`+`/`-`/`neg`/`scale` 演算子、`EpochTime::add_duration`。

## 5. ローカルタイムゾーン FFI

- **JS**: `getTimezoneOffset()`
- **Native**: C スタブ (`tz_native_stub.c`) で `localtime_r` → `tm_gmtoff`
- **WASM**: UTC フォールバック

## 6. GMT/UTC プレフィックス対応

`parse_tz_offset` で `GMT+0900`, `UTC+5:30` 等を受け付ける。
