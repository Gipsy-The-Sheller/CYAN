#!/usr/bin/env bash
#
# Smoke-test BMGE 2.0.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=bmge
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -f "$pkg/BMGE.jar" ]] || die "missing BMGE.jar"
command -v java >/dev/null 2>&1 || die "java (11+) is required"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fna" "$smoke/input.fna"

help_out="$(java -jar "$pkg/BMGE.jar" -h 2>&1 || true)"
[[ "$help_out" == *"BMGE v$version"* ]] \
  || die "unexpected BMGE version output"

(
  cd "$smoke"
  java -jar "$pkg/BMGE.jar" -i input.fna -t NT -o selected.fna \
    > run.log 2>&1
) || {
  tail -n 40 "$smoke/run.log" >&2 || true
  die "BMGE example run failed"
}

[[ -s "$smoke/selected.fna" ]] || die "BMGE produced no output"
records="$(grep -c '^>' "$smoke/selected.fna" || true)"
[[ "$records" == 55 ]] \
  || die "BMGE output has $records records, expected 55"
awk '
  /^>/ {
    if (n == 1) len = length(seq)
    else if (n > 1 && length(seq) != len) bad = 1
    n++; seq = ""; next
  }
  { gsub(/[ \t\r]/, ""); seq = seq $0 }
  END {
    if (n == 1) len = length(seq)
    else if (n > 1 && length(seq) != len) bad = 1
    if (len == 0) bad = 1
    exit bad
  }
' "$smoke/selected.fna" || die "BMGE output sequences have unequal lengths"

log "BMGE smoke test passed ($version, 55 sequences)"
