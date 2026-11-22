#!/usr/bin/env bash
#
# Smoke-test the FAMSA build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=famsa
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/famsa$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged FAMSA: $bin"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$smoke/example.fa"

help_out="$("$bin" -help 2>&1 | tr -d '\r')" || true
grep -q "version $version" <<< "$help_out" \
  || die "unexpected FAMSA version output: $(head -n 2 <<< "$help_out")"

(
  cd "$smoke"
  "$bin" -t 2 example.fa aligned.fa > famsa.log 2>&1
) || {
  tail -n 40 "$smoke/famsa.log" >&2 || true
  die "FAMSA alignment run failed"
}

[[ -s "$smoke/aligned.fa" ]] || die "FAMSA produced no alignment"
n_records="$(grep -c '^>' "$smoke/aligned.fa")"
[[ "$n_records" -eq 6 ]] || die "expected 6 aligned records, got $n_records"

awk '
  /^>/ { if (seen) print length(seq); seen = 1; seq = ""; next }
  { seq = seq $0 }
  END { if (seen) print length(seq) }
' "$smoke/aligned.fa" | sort -u > "$smoke/alnlen"

[[ "$(wc -l < "$smoke/alnlen" | tr -d '[:space:]')" -eq 1 ]] \
  || die "aligned sequences have different lengths"
aln_len="$(tr -d '[:space:]' < "$smoke/alnlen")"
[[ "$aln_len" -gt 0 ]] || die "empty alignment"
log "FAMSA smoke test passed (6 taxa, $aln_len columns)"
