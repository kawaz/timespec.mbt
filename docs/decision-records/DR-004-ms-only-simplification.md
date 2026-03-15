# DR-004: ms 精度への簡素化

- **日付**: 2026-03-15
- **ステータス**: Accepted
- **上書き**: DR-001 の Duration 型設計（enum → newtype）、DR-002 の sub-ms 精度

## 問題

Duration と EpochTime が `Ms(Int64) | MsNs(Int64, Int)` の 2 バリアント enum だった。
sub-ms 精度（us/ns）を保持する設計は以下の複雑さをもたらしていた:

1. **算術演算の複雑化**: Add/Sub/Neg/scale で ms と sub-ms ns の繰り上げ・繰り下げ処理が必要
2. **パーサの二重累積**: parse_duration で total_ms と sub_ms_ns の 2 変数を管理
3. **from_ms_ns の正規化ロジック**: 負値やオーバーフロー時の正規化が複雑
4. **serialize の us/ns 出力**: format_duration で ns → us → ms の分解が必要
5. **実用上の不要さ**: CLI 用途で sub-ms 精度が必要なケースはなく、`@env.now()` も ms 精度

## 決定

### 型を newtype に変更

```moonbit
pub(all) struct Duration(Int64)   // ミリ秒
pub(all) struct EpochTime(Int64)  // epoch からの経過ミリ秒
```

- `enum` → `struct`（newtype）
- `MsNs` バリアント廃止
- 内部値へのアクセス: `.0`
- `derive(Eq, Show, Compare)` で自動導出

### 削除した要素

- `Duration::from_ms_ns()` — 正規化不要に
- `Duration::to_ns()` — ns 精度がないため不要
- `Duration::ms()`, `Duration::sub_ms_ns()` — `.0` でアクセス
- `EpochTime::ms()`, `EpochTime::sub_ms_ns()` — `.0` でアクセス
- `nanosecond`, `microsecond` 定数 — sub-ms 単位廃止
- `us`/`μs`/`ns` パース単位 — エラーとして拒否

### 簡素化された演算

```moonbit
pub impl Add for Duration with add(a, b) { Duration(a.0 + b.0) }
pub impl Neg for Duration with neg(self) { Duration(-self.0) }
pub fn Duration::scale(self, n: Int64) -> Duration { Duration(self.0 * n) }
pub fn EpochTime::add_duration(self, d: Duration) -> EpochTime { EpochTime(self.0 + d.0) }
```

繰り上げ・正規化が完全に不要になった。

## 理由

1. **YAGNI**: CLI 用途で sub-ms 精度は不要。必要になったら再導入できる
2. **複雑さの大幅削減**: 算術演算、パーサ、シリアライザ全てが単純化
3. **newtype の利点**: 型安全性を維持しつつ、ゼロコスト抽象化
4. **MoonBit の新構文**: `struct T(A)` + `.0` アクセスが推奨構文
