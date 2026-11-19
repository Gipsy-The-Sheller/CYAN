#!/usr/bin/env bash
#
# Smoke-test the packaged Treerecs build with the upstream fish example.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=treerecs
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/treerecs$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged treerecs: $bin"

version_all="$("$bin" --version 2>&1 | tr -d '\r')"
[[ "$version_all" == *"Treerecs 1.3"* ]] \
  || die "unexpected Treerecs version: $version_all"
version_out="$(printf '%s\n' "$version_all" | head -n 1)"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/genetree.nwk" "$TOOL_DIR/examples/speciestree.nwk" "$smoke/"

(
  cd "$smoke"
  "$bin" -g genetree.nwk -s speciestree.nwk -o out -O newick:svg -q \
    > run.log 2>&1
) || {
  tail -n 40 "$smoke/run.log" >&2 || true
  die "Treerecs reconciliation failed"
}

out="$smoke/out/genetree.nwk_recs.nwk"
svg="$smoke/out/genetree.nwk_recs.svg"
[[ -s "$out" ]] || die "Treerecs did not write $out"
[[ -s "$svg" ]] || die "Treerecs did not write $svg"
grep -q 'total cost' "$out" || die "Treerecs output is missing the reconciliation cost"
grep -q ';' "$out" || die "Treerecs output is not Newick"
grep -q 'danio_rerio' "$out" || die "Treerecs output is missing the input taxa"

log "Treerecs smoke test passed (fish example, version $version_out)"
