#!/usr/bin/env bash
#
# Smoke-test the packaged Clustal Omega build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=clustalo
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/clustalo$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged clustalo: $bin"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == "1.2.4" ]] \
  || die "unexpected Clustal Omega version: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$smoke/example.fa"

"$bin" -i "$smoke/example.fa" -o "$smoke/example.aln" \
  --outfmt=fasta --force > "$smoke/run.log" 2>&1 || {
    tail -n 40 "$smoke/run.log" >&2 || true
    die "Clustal Omega alignment failed"
  }

[[ -s "$smoke/example.aln" ]] || die "Clustal Omega produced no alignment"
found="$(grep -c '^>' "$smoke/example.aln")"
[[ "$found" -eq 5 ]] || die "expected 5 aligned sequences, got $found"

log "Clustal Omega smoke test passed (5 sequences, version $version_out)"
