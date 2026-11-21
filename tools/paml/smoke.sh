#!/usr/bin/env bash
#
# Smoke-test PAML with the upstream yn00 and codeml examples.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=paml
pkg="$CYAN_BUILD/stage/$tool"
smoke="$CYAN_BUILD/$tool/smoke"
[[ -x "$pkg/yn00$CYAN_EXE" ]] || die "missing packaged yn00"
[[ -x "$pkg/codeml$CYAN_EXE" ]] || die "missing packaged codeml"

rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/abglobin.nuc" "$smoke/"
cp "$TOOL_DIR/examples/yn00.ctl" "$smoke/"
cp "$TOOL_DIR/examples/lysozymeSmall.ctl" "$smoke/"
cp "$TOOL_DIR/examples/lysozymeSmall.nuc" "$smoke/"
cp "$TOOL_DIR/examples/lysozymeSmall.trees" "$smoke/"
cp -a "$pkg/dat" "$smoke/dat"

sed -e 's#examples/abglobin.nuc#abglobin.nuc#' \
    -e 's#outfile = yn#outfile = yn.out#' \
    "$smoke/yn00.ctl" > "$smoke/yn00-local.ctl"
sed -e 's#lysozymeSmall.txt#lysozymeSmall.nuc#' \
    -e 's#outfile = mlc#outfile = mlc.out#' \
    "$smoke/lysozymeSmall.ctl" > "$smoke/lysozymeSmall-local.ctl"

(
  cd "$smoke"
  "$pkg/yn00$CYAN_EXE" yn00-local.ctl > yn00.log 2>&1
) || {
  tail -n 30 "$smoke/yn00.log" >&2 || true
  die "PAML yn00 failed"
}
[[ -s "$smoke/yn.out" ]] || die "yn00 produced no output"
grep -q 'omega' "$smoke/yn.out" || die "yn00 output has no omega table"

(
  cd "$smoke"
  "$pkg/codeml$CYAN_EXE" lysozymeSmall-local.ctl > codeml.log 2>&1
) || {
  tail -n 30 "$smoke/codeml.log" >&2 || true
  die "PAML codeml failed"
}
[[ -s "$smoke/mlc.out" ]] || die "codeml produced no output"
grep -q 'lnL' "$smoke/mlc.out" || die "codeml output has no lnL"
grep -q 'Time used' "$smoke/codeml.log" || die "codeml did not finish cleanly"

log "PAML smoke test passed (yn00 abglobin + codeml lysozyme)"
