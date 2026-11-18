#!/usr/bin/env bash
#
# Smoke-test the packaged ModelTest-NG build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=modeltest-ng
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/bin/modeltest-ng$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged modeltest-ng: $bin"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | grep -m1 'ModelTest-NG v' || true)"
[[ "$version_out" == *"ModelTest-NG v0.1.7"* ]] \
  || die "unexpected ModelTest-NG version output: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/tiny.fas" "$smoke/tiny.fas"

(
  cd "$smoke"
  "$bin" -i tiny.fas -d nt -o result -p 2 \
    --force --disable-checkpoint > run.log 2>&1
) || {
  tail -n 60 "$smoke/run.log" >&2 || true
  die "ModelTest-NG model selection failed"
}

[[ -s "$smoke/result.out" ]] || die "ModelTest-NG produced no result file"
grep -q "Done" "$smoke/result.out" \
  || die "ModelTest-NG result file is incomplete"
grep -q "Best model according to BIC" "$smoke/result.out" \
  || die "ModelTest-NG did not select a BIC model"
[[ -s "$smoke/result.tree" ]] \
  || die "ModelTest-NG did not write a starting tree"

log "ModelTest-NG smoke test passed ($version_out)"
