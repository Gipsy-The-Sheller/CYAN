#!/usr/bin/env bash
#
# Smoke-test the packaged MUSCLE 5 build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=muscle5
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/muscle$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged muscle: $bin"

version_out="$("$bin" -version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"muscle 5.3"* ]] \
  || die "unexpected MUSCLE version output: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$smoke/example.fa"

"$bin" -align "$smoke/example.fa" -output "$smoke/example.aln" \
  > "$smoke/run.log" 2>&1 || {
    tail -n 40 "$smoke/run.log" >&2 || true
    die "MUSCLE alignment failed"
  }

[[ -s "$smoke/example.aln" ]] || die "MUSCLE produced no alignment"
found="$(grep -c '^>' "$smoke/example.aln")"
[[ "$found" -eq 5 ]] || die "expected 5 aligned sequences, got $found"

# All aligned sequences must have the same length.
lengths="$(awk '/^>/{if(seq!=""){print length(seq)};seq="";next}{seq=seq$0}END{print length(seq)}' \
  "$smoke/example.aln" | sort -u | wc -l)"
[[ "$lengths" -eq 1 ]] || die "MUSCLE output sequences have different lengths"

log "MUSCLE smoke test passed (5 sequences, version: $version_out)"
