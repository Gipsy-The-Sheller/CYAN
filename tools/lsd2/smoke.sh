#!/usr/bin/env bash
#
# Smoke-test the built LSD2 binary with the upstream H1N1 example.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=lsd2
build="$CYAN_BUILD/$tool"
bin="$build/$tool$CYAN_EXE"
out="$build/smoke.out"
log_file="$build/smoke.log"

[[ -x "$bin" ]] || die "missing binary: $bin (run build.sh first)"

rm -f "$out" "$log_file"
"$bin" \
  -i "$TOOL_DIR/examples/rooted_tree/h1n1_phyml.tree" \
  -d "$TOOL_DIR/examples/rooted_tree/h1n1.date" \
  -s 1000 \
  -o "$out" > "$log_file" 2>&1 || {
    tail -n 40 "$log_file" >&2 || true
    die "LSD2 exited non-zero"
  }

grep -q 'Dating results' "$out" || {
  tail -n 40 "$log_file" >&2 || true
  die "LSD2 output does not contain a dating result"
}
grep -q 'rate ' "$out" || {
  tail -n 40 "$out" >&2 || true
  die "LSD2 output does not contain an estimated rate"
}

log "LSD2 smoke test passed"
grep -E 'rate .*tMRCA' "$out" | tail -n 1
