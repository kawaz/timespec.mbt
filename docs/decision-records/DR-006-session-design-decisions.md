# DR-006: セッション中の設計決定まとめ

- **日付**: 2026-03-16
- **ステータス**: Accepted

## 1. parse_range を since~/until~ 2引数方式に変更

ParseContext（Since/Until/Range）を廃止し、`since~` と `until~` を個別に受け取る方式に変更。
`input~` で `~` 形式（`"5d~3m"`, `"5d~"`, `"~3m"`）も対応。

**理由**: 2引数ならコンテキスト不要。アンカー解決は Mixed ルール（片方 Absolute なら anchor）のみで十分。`~` 分割はアプリ側の責務だが、便利のため `input~` でも受け付ける。

## 2. ユニットエイリアスと ago 修飾子

Duration パーサに長いユニット名（`hour`, `minutes`, `week` 等）と `ago` 修飾子を追加。

`ago` はグループレベル反転:
- グループ = 明示的 `+`/`-` で区切られた連続セグメント
- `ago` はグループを反転し、次のグループを開始
- 合成可能性を保証: `30 minutes ago` の意味は前後に何を置いても変わらない

**理由**: `3 minutes ago` のような自然言語風入力は CLI で便利。グループレベル反転により部分式の合成可能性が保たれる。

## 3. EpochTime 型の導入と命名

`TimeSpec::Absolute(Int64)` → `TimeSpec::Absolute(EpochTime, Duration)` に変更。

命名の変遷: `Absolute` → `Instant` → `Epoch` → `EpochTime`

- `Absolute`: TimeSpec のバリアント名と衝突
- `Instant`: 汎用的すぎて「何の instant？」となる
- `Epoch`: epoch 自体は基準点（1970-01-01）を指す語
- `EpochTime`: epoch からの経過時間。`Duration`（期間）と対をなす概念

## 4. カスタム epoch パラメータ

`parse_timespec` と `parse_range` に `epoch~` パラメータを追加。Snowflake 等の Unix Epoch 以外の基準点に対応。

**理由**: EpochTime は概念的に「ある基準点からの経過時間」であり、基準点は差し替え可能であるべき。

## 5. ms 精度への簡素化

`Duration` と `EpochTime` を `Ms(Int64) | MsNs(Int64, Int)` enum から `struct(Int64)` newtype に簡素化。`us`/`ns` ユニットを廃止。

**理由**: CLI 用途で sub-ms 精度は実用上不要。newtype 化で演算子やコードが大幅にシンプルになった。

## 6. Duration 定数と演算子

`millisecond`, `second`, `minute`, `hour`, `day`, `week` 定数と `+`, `-`, `neg`, `scale` 演算子を追加。

**理由**: `hour.scale(2L) + minute.scale(30L)` のように直感的に Duration を構築できる。

## 7. ローカルタイムゾーン FFI

- **JS**: `getTimezoneOffset()` で完全実装
- **Native**: C スタブ (`tz_native_stub.c`) で `localtime_r` → `tm_gmtoff` を読み取り
- **WASM**: UTC フォールバック（エコシステム全体で未対応）

**理由**: `TzOffset::Local` を実用的に使えるようにする。Native は当初バイトオフセット読みだったが、moonbitlang/x の C スタブ方式に倣い安全な実装に変更。

## 8. default_tz_offset と make_parse_datetime

TZ なし datetime のデフォルト解釈は UTC。Local にしたい場合は `make_parse_datetime(default_tz_offset=Local)` でパーサを生成。

**理由**: ライブラリのデフォルトは安全側（UTC）。CLI アプリが Local を使いたければ明示的に指定する。ISO 8601 では TZ なし = ローカルだが、再現性の観点から UTC デフォルトが定石。

## 9. GMT プレフィックス対応

`parse_tz_offset` で `GMT`/`UTC` をプレフィックスとして除去してからパース。`GMT+0900`, `UTC+5:30` 等に対応。

**理由**: GMT は他のロケール文字列と違い TZ 定義の基本側にある。単独なら `Utc`、オフセット付きならプレフィックス除去してパース。
