#!/usr/bin/env bash
#
# Smoke-test FastME with a small PHYLIP distance matrix.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=fastme
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/fastme$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged FastME: $bin"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/dist.txt" "$smoke/"

version_out="$("$bin" -V 2>&1 | tr -d '\r' | grep -o 'FastME [0-9.]*' | head -n 1)"
[[ "$version_out" == *"$version"* ]] \
  || die "unexpected FastME version output: $version_out"

(
  cd "$smoke"
  "$bin" -i dist.txt -o tree.nwk > run.log 2>&1
) || {
  tail -n 30 "$smoke/run.log" >&2 || true
  die "FastME distance-tree run failed"
}

[[ -s "$smoke/tree.nwk" ]] || die "FastME produced no tree"
first="$(head -c 1 "$smoke/tree.nwk")"
last="$(tr -d '[:space:]' < "$smoke/tree.nwk" | tail -c 1)"
[[ "$first" == "(" && "$last" == ";" ]] \
  || die "FastME output is not a Newick tree"
for taxon in A B C D; do
  grep -q "$taxon" "$smoke/tree.nwk" || die "FastME tree is missing $taxon"
done

log "FastME smoke test passed ($version, 4 taxa)"
