#!/usr/bin/env bash
#
# Smoke-test the packaged YGBlocks build with FASTA and PHYLIP input.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=ygblocks
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/Gblocks$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged YGBlocks: $bin"

help_out="$("$bin" -h 2>&1 | tr -d '\r')"
[[ "$help_out" == *"YGBlocks"* ]] \
  || die "unexpected YGBlocks help output"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fas" "$smoke/example.fas"
cp "$TOOL_DIR/examples/example.phy" "$smoke/example.phy"

params=(-p=t -q=n -r=n -e=-gb -b6=n -t=d -b3=3 -b4=2)

(
  cd "$smoke"
  "$bin" example.fas "${params[@]}" > fasta.log 2>&1
) || {
  tail -n 40 "$smoke/fasta.log" >&2 || true
  die "YGBlocks FASTA run failed"
}

(
  cd "$smoke"
  "$bin" example.phy "${params[@]}" > phylip.log 2>&1
) || {
  tail -n 40 "$smoke/phylip.log" >&2 || true
  die "YGBlocks PHYLIP run failed"
}

[[ -s "$smoke/example.fas-gb.fa" ]] || die "missing selected FASTA output"
[[ -s "$smoke/example.phy-gb.fa" ]] || die "missing PHYLIP selected output"
cmp -s "$smoke/example.fas-gb.fa" "$smoke/example.phy-gb.fa" \
  || die "FASTA and PHYLIP input produced different selected alignments"

report="$smoke/example.fas-gb.txt"
[[ -s "$report" ]] || die "missing masked report"
[[ "$(head -n 1 "$report" | tr -d '\r')" == "10 80" ]] \
  || die "unexpected report header"
grep -q '[a-z]' "$report" || die "report does not contain masked lowercase"
grep -q '\.' "$report" || die "report does not contain gap dots"

log "YGBlocks smoke test passed (FASTA + PHYLIP, masked report)"
