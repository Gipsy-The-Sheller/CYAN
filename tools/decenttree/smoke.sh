#!/usr/bin/env bash
#
# Smoke-test the DecentTree build with the algorithms YR-MPE exposes.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=decenttree
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/decenttree$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged DecentTree: $bin"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.mldist" "$smoke/example.mldist"

taxa=(Alpha Beta Gamma Delta Epsilon Zeta)
algorithms=(BIONJ-R BIONJ-V NJ-R-D ONJ-R ONJ-R-V AUCTION)

for alg in "${algorithms[@]}"; do
  out="$smoke/$alg.nwk"
  log_file="$smoke/$alg.log"
  "$bin" -in "$smoke/example.mldist" -out "$out" -t "$alg" -no-banner \
    > "$log_file" 2>&1 || {
      tail -n 40 "$log_file" >&2 || true
      die "DecentTree $alg exited non-zero"
    }
  [[ -s "$out" ]] || die "DecentTree $alg produced no tree"
  grep -q ';' "$out" || die "DecentTree $alg output is not Newick"
  for name in "${taxa[@]}"; do
    grep -q "$name" "$out" || die "DecentTree $alg output is missing $name"
  done
  found="$(grep -o 'Alpha\|Beta\|Gamma\|Delta\|Epsilon\|Zeta' "$out" \
    | sort -u | wc -l)"
  [[ "$found" -eq "${#taxa[@]}" ]] \
    || die "DecentTree $alg output does not contain all ${#taxa[@]} taxa"
done

log "DecentTree smoke test passed (${#algorithms[@]} algorithms, ${#taxa[@]} taxa)"
