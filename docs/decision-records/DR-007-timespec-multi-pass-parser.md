# DR-007: TimeSpec パーサのマルチパス方式への再設計

- **日付**: 2026-03-16
- **ステータス**: Accepted

## 問題

現行の `parse_timespec` は頭からスキャンして YYYY パターンで datetime を推測し、`try_parse_datetime_shrinking` で最長一致を縮小試行する方式。以下の問題がある:

1. **脆弱**: datetime と duration の境界判定がヒューリスティック
2. **場当たり的**: `@` の検出が先頭/末尾/途中で分散
3. **拡張困難**: `@10:30`（time-of-day リセット）のような新概念を入れる余地がない
4. **TzOffset の統一的な扱いがない**

## 決定

マルチパス方式に再設計する。Duration が構文的に明確（数値 + ユニット文字）なので先に抽出し、残りを datetime として処理する。

### パースフェーズ

#### Phase 1: Duration セグメントの抽出

Duration は構文的に明確: `([+-])?\s*(\d[\d_]*(\.\d[\d_]*)?)\s*(w|wk|week|weeks|d|day|days|h|hr|hour|hours|m|min|minute|minutes|s|sec|second|seconds|ms|millisecond|milliseconds)\s*(ago)?`

これを繰り返しマッチして全 duration セグメントを回収。`parse_duration` に渡して `Duration` を得る。

**重要**: Duration を先に除去する。`@` は除去しない（`2026-1-1@1d` で `@` を先に除去すると `2026-1-11d` になってしまうため）。

#### Phase 2: `@` マーカーの検出

Duration 除去後の残り文字列から `@` の有無を確認し `has_at` フラグを記録。

#### Phase 3: Time-of-day パターンの検出

`@` がある場合、残り文字列から `@HH:MM[:SS[.mmm]][±TzOffset]` パターンを検出:
- `@10:30` → time_part = (10, 30, 0, 0)
- `@00:00` → midnight リセット
- TzOffset 付き → `tz_offset_timepart` として保存

`@` なしの time-of-day パターンは検出しない（duration の数値と曖昧になるため）。

検出したらパターンを除去。

#### Phase 3.5: Raw epoch ms の検出

`@` がある場合、非 duration 残りが**数字のみ**（区切り文字 `-`/`/`/`:` なし）ならば、raw epoch ms として解釈する。

- `@1773632079000` → `EpochTime(1773632079000)` — 生の epoch ms 値
- `@2026` → `EpochTime(2026)` — 2ms 後（数字のみなので datetime ではない）
- `@2026-01` → datetime（区切りがあるので Phase 4 へ）

判定基準: `@` 付きで、残り文字列が `[0-9]+` のみ → raw epoch ms。
`date -d @EPOCH` と同じ規約。

#### Phase 4: datetime パース

Phase 1-3.5 で duration・@・time-of-day・raw epoch を除去した残りが datetime 候補。

- 非空 → `parse_datetime~` に渡してパース
- 空 → datetime なし

datetime パース時の TzOffset 回収:
- `detect_tz_suffix` でパーサ非依存に元文字列の末尾から TZ サフィックスを検出（→ DR-009）
- 内部パーサ・外部プラガブルパーサを問わず同一の仕組みで TZ 情報を回収
- `parse_datetime~` のシグネチャ `(String) -> Int64?` は変更なし

#### Phase 5: EpochTime の構築

1. datetime パース結果あり → datetime の epoch_ms が基準
2. datetime なし + `@` あり → `now~()` が基準
3. datetime なし + `@` なし → `now~()` が基準（Relative）

Time-of-day リセット（Phase 3 で検出した場合）:
- 基準の EpochTime を `default_tz_offset` を考慮してローカル midnight に切り落とし
- time_part を加算: `+ hour * 3600000 + min * 60000 + sec * 1000 + ms`

TzOffset 整合性チェック:

time-of-day リセット時、datetime 側と time-of-day 側の **effective TzOffset** が一致しなければエラー。

- effective TzOffset = 明示指定があればそれ、なければ `default_tz_offset`
- `effective_datetime != effective_timeofday` → `ParseError("ambiguous timezone offset")`

チェックは**双方向**。どちら側が明示でも、相手側と不一致ならエラー。

例（`default_tz_offset=Hour(9)` の場合）:

| 入力 | datetime TZ | time-of-day TZ | effective | 結果 |
|---|---|---|---|---|
| `@2026-03-10 @00:00` | 暗黙 JST | 暗黙 JST | JST = JST | OK |
| `@2026-03-10+09:00 @00:00+09:00` | 明示 JST | 明示 JST | JST = JST | OK |
| `@2026-03-10 @00:00+09:00` | 暗黙 JST | 明示 JST | JST = JST | OK |
| `@00:00Z` | なし（now） | 明示 UTC | UTC midnight | OK |
| `@2026-03-10 @00:00Z` | 暗黙 JST | 明示 UTC | JST ≠ UTC | **ParseError** |
| `2026-03-10Z @20:00` | 明示 UTC | 暗黙 JST | UTC ≠ JST | **ParseError** |
| `2026-03-10Z @20:00Z` | 明示 UTC | 明示 UTC | UTC = UTC | OK |

理由: time-of-day リセットは「日付部分を保持して時刻だけ置き換える」操作だが、TzOffset が異なると日付部分自体が変わるため、結果が決定できない。
例: `@2026-03-10 @00:00Z` で JST の 3/10 = UTC の 3/9 15:00 → `2026-03-10T00:00Z` と `2026-03-09T00:00Z` のどちらか不明。

#### Phase 6: TimeSpec の構築

- `@` あり or datetime あり → `Absolute(EpochTime, Duration)`
- それ以外 → `Relative(EpochTime, Duration)`

### parse_timespec のシグネチャ変更

```moonbit
pub fn parse_timespec(
  input : String,
  epoch~ : EpochTime = EpochTime(0L),
  default_sign~ : Sign = Plus,
  default_tz_offset~ : TzOffset = Utc,
  now~ : () -> UInt64 = @env.now,
  parse_datetime~ : (String) -> Int64? = default_parse_datetime
) -> TimeSpec raise ParseError
```

`default_tz_offset~` を追加。`parse_range` にも同様に追加して `parse_timespec` に透過的に渡す。

### 入力例

| 入力 | Phase 1 (Duration) | Phase 2-3 (@/time) | Phase 4 (datetime) | 結果 |
|---|---|---|---|---|
| `5m` | Duration(-5m) | なし | なし | Relative(now-5m, -5m) |
| `@5m` | Duration(-5m) | has_at=true | なし | Absolute(now-5m, -5m) |
| `1h@30m` | Duration(-1h30m) | has_at=true | なし | Absolute(now-1h30m, -1h30m) |
| `2026-03-01` | なし | なし | 2026-03-01 | Absolute(dt, 0) |
| `2026-03-01+5h` | Duration(+5h) | なし | 2026-03-01 | Absolute(dt+5h, +5h) |
| `30m2026-03-01+5h` | Duration(-30m, +5h) | なし | 2026-03-01 | Absolute(dt-30m+5h, -30m+5h) |
| `@10:30` | なし | has_at=true, time=(10,30,0,0) | なし | Absolute(today@10:30, 0) |
| `@00:00~3h` | parse_range で分割 | - | - | since=Abs(today@00:00), until=Rel(+3h) |

## 理由

- Duration のパターンは構文的に明確（数値 + ユニット文字）。先に抽出するのが自然
- 「残りが datetime」という考え方により、datetime 検出のヒューリスティックが不要になる
- Time-of-day リセット（`@10:30`）が自然に組み込める
- TzOffset の整合性チェックが統一的に行える
- 各フェーズが独立しておりテスト・デバッグが容易

## 影響

- `parse_timespec` のフルリライト
- `find_datetime`, `try_parse_datetime_shrinking`, `parse_duration_segment`, `check_trailing_at` 等の内部関数を廃止
- `parse_timespec` に `default_tz_offset~` パラメータ追加
- `parse_range` にも `default_tz_offset~` パラメータ追加
- 既存テストの外部動作は同一であるべき（リファクタリング）
