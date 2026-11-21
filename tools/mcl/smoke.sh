#!/usr/bin/env bash
#
# Smoke-test MCL on a two-cluster graph.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=mcl
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/mcl$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged MCL: $bin"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.abc" "$smoke/"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"mcl $version"* ]] \
  || die "unexpected MCL version output: $version_out"

(
  cd "$smoke"
  "$bin" example.abc --abc -I 2.0 -o clusters.txt > run.log 2>&1
) || {
  tail -n 30 "$smoke/run.log" >&2 || true
  die "MCL clustering failed"
}

[[ -s "$smoke/clusters.txt" ]] || die "MCL produced no clusters"
for taxon in a b c d e f; do
  grep -q "$taxon" "$smoke/clusters.txt" || die "MCL output is missing $taxon"
done
grep -q '2 clusters found' "$smoke/run.log" \
  || die "MCL did not report two clusters"

log "MCL smoke test passed ($version, 2 clusters)"
