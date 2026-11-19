#!/usr/bin/env bash
#
# Smoke-test the FastTree build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=fasttree
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/FastTree$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged FastTree: $bin"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$smoke/example.fa"

version_out="$("$bin" -help 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"FastTree $version"* ]] \
  || die "unexpected FastTree version output: $version_out"

check_tree() {
  local tree="$1"
  [[ -s "$tree" ]] || die "FastTree produced no tree"
  local first last
  first="$(head -c 1 "$tree")"
  last="$(tr -d '[:space:]' < "$tree" | tail -c 1)"
  [[ "$first" == "(" && "$last" == ";" ]] \
    || die "FastTree output is not a Newick tree: $tree"
  for taxon in alpha beta gamma delta epsilon zeta; do
    grep -q "$taxon" "$tree" || die "tree is missing $taxon"
  done
}

(
  cd "$smoke"
  "$bin" -nt -out serial.nwk example.fa > serial.log 2>&1
) || {
  tail -n 30 "$smoke/serial.log" >&2 || true
  die "FastTree nucleotide run failed"
}
check_tree "$smoke/serial.nwk"

if [[ -x "$pkg/FastTreeMP$CYAN_EXE" ]]; then
  (
    cd "$smoke"
    OMP_NUM_THREADS=2 "$pkg/FastTreeMP$CYAN_EXE" -nt \
      -out threaded.nwk example.fa > threaded.log 2>&1
  ) || {
    tail -n 30 "$smoke/threaded.log" >&2 || true
    die "FastTreeMP nucleotide run failed"
  }
  check_tree "$smoke/threaded.nwk"
  log "FastTree smoke test passed (FastTree + FastTreeMP, 6 taxa)"
else
  log "FastTree smoke test passed (serial, 6 taxa)"
fi
