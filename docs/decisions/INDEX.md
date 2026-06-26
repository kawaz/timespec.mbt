# Decision Records 一覧

## Active

- [DR-0003: カスタム epoch パラメータ](./DR-0003-custom-epoch-parameter.md) — `epoch?` パラメータで Snowflake 等の独自 epoch を扱えるようにする
- [DR-0005: TzOffset の範囲バリデーションと pub(all) 維持](./DR-0005-tz-offset-range-validation.md) — `parse_tz_offset` で ±24 時間に制限。コンストラクタは `pub(all)` のまま
- [DR-0006: 設計決定まとめ](./DR-0006-session-design-decisions.md) — 1 セッションでまとまった複数の判断（型表現、命名、再シリアライズ方針）
- [DR-0007: TimeSpec パーサのマルチパス方式への再設計](./DR-0007-timespec-multi-pass-parser.md) — 単一パスを 6 フェーズのマルチパスに分割
- [DR-0008: 追加の設計決定](./DR-0008-additional-design-decisions.md) — 複数の追加判断（一部はセクション 3 のみ DR-0009 で破棄）
- [DR-0009: 部分日付の禁止と detect_tz_suffix の新設](./DR-0009-partial-date-prohibition-and-detect-tz-suffix.md) — `YYYY` / `YYYY-MM` を禁止し、TZ 末尾検出を分離

## Archived

<!-- 現役の文脈を汚す古い DR は decisions/archive/ に退避し、ここに記載 -->

## Moved to research/

<!-- 判断記録の体を成さなくなり research/ に降格した DR -->

## Superseded

<!-- 後続 DR に上書きされた DR (Status: Superseded by DR-XXXX) -->
