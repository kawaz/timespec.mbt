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
[script]
check-on-default-branch:
    if ! bump-semver vcs is on-default-branch; then
        cur=$(bump-semver vcs get current-branch 2>/dev/null || echo "(ambiguous)")
        bn=$(bump-semver vcs get default-branch)
        printf >&2 "⚠ 現在 '%s' bookmark/branch にいます。%s に合流してから push してください\n  1. just sync         # %s@origin に rebase\n  2. just promote      # %s bookmark を current commit に forward\n" "$cur" "$bn" "$bn" "$bn"
        exit 1
    fi

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

# src/ or moon.mod が変わったら VERSION 上げ忘れを止める
# test 専用追加 (*_wbtest.mbt / *_test.mbt) は bump 不要なので exclude
check-version-bumped: (_check-version-bumped "src/" "moon.mod" "src/moon.pkg")

[private]
[script]
_check-version-bumped *target_paths:
    if ! bump-semver vcs diff -q main@origin -- "$@" --excludes 'glob:src/**/*_wbtest.mbt' --excludes 'glob:src/**/*_test.mbt'; then
        # 初回 release では origin/main に VERSION が無いので compare gt が exit 2 で返る (path not found)。
        # その場合は「VERSION 新規追加 = bump 済」とみなして OK 扱い。
        set +e
        bump-semver compare gt VERSION vcs:main@origin 2>/dev/null
        cmp_exit=$?
        set -e
        case "$cmp_exit" in
            0) ;;  # VERSION > origin の VERSION: OK
            2)
                echo "Initial release: origin/main has no VERSION yet, treating as bumped"
                ;;
            *)
                bump-semver compare gt VERSION vcs:main@origin  # 再度実行してエラーを表示
                exit "$cmp_exit"
                ;;
        esac
    fi

# VERSION を bump (= patch/minor/major) して release commit を作成
# VERSION + moon.mod の version フィールドを同期更新する
[script]
bump-version level="patch": ensure-clean
    bump-semver "$1" VERSION --write --quiet
    new=$(bump-semver get VERSION)
    # moon.mod の version 行を同期
    sed -i.bak -E "s/^version = \".*\"\$/version = \"${new}\"/" moon.mod && rm moon.mod.bak
    bump-semver vcs commit -m "Release v${new}" VERSION moon.mod

# push to origin/main with canonical gates
push: check-on-default-branch ci check-outdated-translations check-version-bumped
    bump-semver vcs push --branch main --jj-bookmark-auto-advance
    @echo "[hint] gh-monitor:watch-workflow --sha $(bump-semver vcs get commit-id --rev main) --on-success release.yml 'just on-success-release' kawaz/timespec.mbt"

# release.yml workflow が success になった時のフォローアクション
# (現状は version 反映確認のみ。配布物が増えたら拡張する)
on-success-release:
    @echo "Released v$(bump-semver get VERSION)"
