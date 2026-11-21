#!/usr/bin/env bash
#
# Smoke-test ASTER v1.25: ASTRAL-Pro3 and ASTRAL-IV.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=aster
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$pkg/astral-pro3$CYAN_EXE" ]] || die "missing astral-pro3"
[[ -x "$pkg/astral4$CYAN_EXE" ]] || die "missing astral4"

rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/tiny.trees" "$smoke/"

version_out="$("$pkg/astral-pro3$CYAN_EXE" -h 2>&1 | tr -d '\r' | head -n 3)"
[[ "$version_out" == *"v$version"* ]] \
  || die "unexpected ASTER version: $version_out"

check_tree() {
  local tree="$1"
  [[ -s "$tree" ]] || die "ASTER produced no tree"
  for taxon in a b c d e; do
    grep -q "$taxon" "$tree" || die "tree is missing $taxon"
  done
}

(
  cd "$smoke"
  "$pkg/astral-pro3$CYAN_EXE" -i tiny.trees -o pro.tree -t 1 > pro.log 2>&1
) || {
  tail -n 40 "$smoke/pro.log" >&2 || true
  die "ASTRAL-Pro3 failed"
}
check_tree "$smoke/pro.tree"

(
  cd "$smoke"
  "$pkg/astral4$CYAN_EXE" -i tiny.trees -o astral.tree -t 1 > astral.log 2>&1
) || {
  tail -n 40 "$smoke/astral.log" >&2 || true
  die "ASTRAL-IV failed"
}
check_tree "$smoke/astral.tree"

log "ASTER smoke test passed (ASTRAL-Pro3 + ASTRAL-IV, 5 taxa)"
