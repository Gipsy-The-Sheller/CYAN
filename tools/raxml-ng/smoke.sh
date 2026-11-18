#!/usr/bin/env bash
#
# Smoke-test the packaged RAxML-NG build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=raxml-ng
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/bin/raxml-ng$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged raxml-ng: $bin"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | grep -m1 'RAxML-NG v' || true)"
[[ "$version_out" == *"RAxML-NG v. 1.2.2"* ]] \
  || die "unexpected RAxML-NG version output: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/tiny.fas" "$smoke/tiny.fas"

(
  cd "$smoke"
  "$bin" --msa tiny.fas --model GTR+G --prefix result \
    --threads 2 --seed 2 --redo --all --bs-trees 10 > run.log 2>&1
) || {
  tail -n 60 "$smoke/run.log" >&2 || true
  die "RAxML-NG all-in-one analysis failed"
}

[[ -s "$smoke/result.raxml.bestTree" ]] \
  || die "RAxML-NG did not write a best tree"
[[ -s "$smoke/result.raxml.support" ]] \
  || die "RAxML-NG did not write bootstrap support values"
grep -q "Final LogLikelihood:" "$smoke/run.log" \
  || die "RAxML-NG did not report a final likelihood"
grep -q "Best ML tree saved" "$smoke/run.log" \
  || die "RAxML-NG did not finish the ML search"

log "RAxML-NG smoke test passed ($version_out)"
