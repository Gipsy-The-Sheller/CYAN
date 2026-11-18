#!/usr/bin/env bash
#
# Smoke-test the packaged MPBoot build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=mpboot
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/bin/mpboot$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged mpboot: $bin"

version_out="$("$bin" -h 2>&1 | tr -d '\r' | grep -m1 'MPBoot version' || true)"
[[ "$version_out" == *"MPBoot version 1.1.1"* ]] \
  || die "unexpected MPBoot version output: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/tiny.fas" "$smoke/tiny.fas"

(
  cd "$smoke"
  "$bin" -s tiny.fas -pre result -n 10 -seed 2 > run.log 2>&1
) || {
  tail -n 60 "$smoke/run.log" >&2 || true
  die "MPBoot analysis failed"
}

[[ -s "$smoke/result.treefile" ]] \
  || die "MPBoot did not write a tree file"
grep -q 'BEST SCORE FOUND' "$smoke/run.log" \
  || die "MPBoot did not report a best parsimony score"
head -c 1 "$smoke/result.treefile" | grep -q '(' \
  || die "MPBoot tree file is not Newick"

log "MPBoot smoke test passed ($version_out)"
