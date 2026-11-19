#!/usr/bin/env bash
#
# Smoke-test the packaged ASTER2 astral and caster binaries.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=aster2
pkg="$CYAN_BUILD/stage/$tool"
astral="$pkg/astral$CYAN_EXE"
caster="$pkg/caster$CYAN_EXE"
[[ -x "$astral" ]] || die "missing packaged astral: $astral"
[[ -x "$caster" ]] || die "missing packaged caster: $caster"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/tiny.trees" "$smoke/tiny.trees"
cp "$TOOL_DIR/examples/tiny.phy" "$smoke/tiny.phy"

version_out="$("$astral" -h 2>&1 | tr -d '\r' | grep -m1 'v2\.6' || true)"
[[ -n "$version_out" ]] || die "could not determine ASTER2 version"
[[ "$version_out" == *"v2.6"* ]] || die "unexpected ASTER2 version: $version_out"

(
  cd "$smoke"
  "$astral" -i tiny.trees -o astral.nwk -t 1 -u none -l none --no-log \
    > astral.log 2>&1
) || {
  tail -n 40 "$smoke/astral.log" >&2 || true
  die "ASTER2 astral failed"
}
[[ -s "$smoke/astral.nwk" ]] || die "astral produced no tree"
for name in A B C D E; do
  grep -q "$name" "$smoke/astral.nwk" || die "astral output is missing taxon $name"
done

(
  cd "$smoke"
  "$caster" -i tiny.phy -o caster.nwk -t 1 -u none -l none --no-log \
    > caster.log 2>&1
) || {
  tail -n 40 "$smoke/caster.log" >&2 || true
  die "ASTER2 caster failed"
}
[[ -s "$smoke/caster.nwk" ]] || die "caster produced no tree"
for name in Alpha Beta Gamma Delta Epsilon; do
  grep -q "$name" "$smoke/caster.nwk" \
    || die "caster output is missing taxon $name"
done

log "ASTER2 smoke test passed ($version_out; astral + caster)"
