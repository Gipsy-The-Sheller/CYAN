#!/usr/bin/env bash
#
# Smoke-test the packaged trimAl build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=trimal
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/bin/trimal$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged trimal: $bin"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | grep -m1 'trimAl v' || true)"
[[ "$version_out" == *"trimAl v1.5"* ]] \
  || die "unexpected trimAl version output: $version_out"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fas" "$smoke/example.fas"

(
  cd "$smoke"
  "$bin" -in example.fas -out trimmed.fas -gt 0.5 > trim.log 2>&1
) || {
  tail -n 40 "$smoke/trim.log" >&2 || true
  die "trimAl trimming failed"
}
[[ -s "$smoke/trimmed.fas" ]] || die "trimAl produced an empty alignment"
grep -q '^>' "$smoke/trimmed.fas" \
  || die "trimAl output does not look like FASTA"

log "trimAl smoke test passed ($version_out)"
