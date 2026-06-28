---
title: release.yml semver gate に latest-release 並列 check 追加 (DR-0039 canonical 同期)
status: open
category: request
created: 2026-06-28T20:10:40+09:00
last_read:
open_entered: 2026-06-28T20:10:40+09:00
wip_entered:
blocked_entered:
pending_entered:
discarded_entered:
resolved_entered:
discard_reason:
pending_reason:
close_reason:
blocked_by:
origin: bump-semver dogfood 報告
---

# release.yml semver gate に latest-release 並列 check 追加 (DR-0039 canonical 同期)

## 概要

release.yml の semver gate を DR-0039 canonical pattern に同期する。本リポは `latest-tag` 単独 + `gh release view` の B 型であり、`latest-release` 並列 check が不足している。

## 背景

bump-semver canonical (DR-0039) で release.yml の semver gate pattern が更新された。本リポは `latest-tag` 単独 + `gh release view` の B 型。

## 現状 (release.yml L56-89 該当)

`vcs get latest-tag` + `gh release view` のみ、`latest-release` 並列 check 無し。kuu.mbt と同型 (moon.mod 整合 check は本リポでは不要)。

## 修正方針

`latest-release` 並列 check を追加。canonical pattern は bump-semver の release.yml と DR-0039 参照。

## 参考

- bump-semver の `.github/workflows/release.yml`
- bump-semver の docs/decisions/DR-0039-release-yml-semver-gate-pattern.md
- kawaz/die dogfood 報告: session 911732b3、2026-06-28

## 優先度

中 (= B 型)。bump-semver v0.43.0 release 後に着手推奨。

## 受け入れ条件

- [ ] release.yml に `latest-release` 並列 check が追加されている
- [ ] DR-0039 canonical pattern (B 型) と整合している
- [ ] CI で release が正常に動作する

## TODO

<!-- wip 時のみ -->

- [ ] bump-semver release.yml と DR-0039 の最新 canonical pattern を確認
- [ ] 本リポ release.yml に `latest-release` 並列 check を追加
- [ ] CI で動作確認
