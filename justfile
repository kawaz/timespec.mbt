# kawaz/timespec — MoonBit CLI time-spec parser library
#
# Canonical task runner. Modeled after kawaz/bump-semver's justfile and
# kawaz/kuu.mbt's MoonBit adaptation. Recipes delegate VCS-shaped
# operations (commit / push / clean check / diff) and translation-pair
# freshness checks to `bump-semver vcs` subcommands.

set shell := ["bash", "-euo", "pipefail", "-c"]

set script-interpreter := ["bash", "-euo", "pipefail"]

set positional-arguments

# default: lint + test
default: lint test

# show the recipe list
list:
    @just --list --unsorted

# === Lint ===

# Format check + type check (warnings as errors)
lint: fmt-check check

# Format check only (no modification)
fmt-check:
    moon fmt --check

# Format code (auto-fix)
fmt:
    moon fmt

# Type check with warnings as errors
check:
    moon check --deny-warn

# === Test ===

# Run tests (native target)
test:
    moon test --target native

# Run tests on all targets (native / wasm / wasm-gc / js)
test-all:
    moon test --target all

# Update snapshot tests
test-update:
    moon test --update

# === Utilities ===

# Generate type definition files (.mbti)
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# === CI ===

# Full CI pipeline: lint + test-all + info
ci: lint test-all info

# === Push / Release flow (bump-semver canonical 模倣) ===

# working copy clean check (= 未コミット変更を巻き込ませない)
[private]
ensure-clean:
    bump-semver vcs is clean

# default branch (= main) bookmark に居るかを確認
[private]
check-on-default-branch:
    bump-semver vcs is on-default-branch

# 現在の worktree を default branch (= origin/<default>) に rebase
sync:
    bump-semver vcs sync --onto $(bump-semver vcs get default-branch)@origin

# default branch bookmark を現在の commit に forward (push しない)
promote:
    bump-semver vcs promote

# 翻訳ペアの freshness check (= ja 正本が更新されたら en も追従しているか検証)
[private]
check-outdated-translations: ensure-clean
    bump-semver vcs outdated 'glob:**/*-ja.md' '$1/$2.md'

# src/ or moon.mod が変わったら moon.mod の version 上げ忘れを止める
# test 専用追加 (*_wbtest.mbt / *_test.mbt) は bump 不要なので exclude
check-version-bumped: (_check-version-bumped "src/" "moon.mod" "src/moon.pkg")

[private]
_check-version-bumped *target_paths:
    if ! bump-semver vcs diff -q main@origin -- "$@" --excludes 'glob:src/**/*_wbtest.mbt' --excludes 'glob:src/**/*_test.mbt'; then bump-semver compare gt moon.mod vcs:main@origin; fi

# moon.mod の version を bump (= patch/minor/major) して release commit を作成
bump-version level="patch": ensure-clean
    bump-semver "$1" moon.mod --write --quiet
    bump-semver vcs commit -m "Release v$(bump-semver get moon.mod)" moon.mod

# push to origin/main with canonical gates
push: check-on-default-branch ci check-outdated-translations check-version-bumped
    bump-semver vcs push --branch main --jj-bookmark-auto-advance
    @echo "[hint] gh-monitor:watch-workflow --sha $(bump-semver vcs get commit-id --rev main) --on-success release.yml 'just on-success-release' kawaz/timespec.mbt"

# release.yml workflow が success になった時のフォローアクション
on-success-release:
    @echo "Released v$(bump-semver get moon.mod)"
