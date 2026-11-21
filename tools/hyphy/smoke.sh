#!/usr/bin/env bash
#
# Smoke-test HyPhy and its packaged batch library.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=hyphy
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/hyphy$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged HyPhy binary"
[[ -x "$pkg/hyphy-run" ]] || die "missing hyphy-run wrapper"
[[ -d "$pkg/res" ]] || die "missing HyPhy res/ library"

version_out="$(HYPHY_PATH="$pkg/res" "$bin" --version 2>&1 | tr -d '\r' | head -n 3)"
[[ "$version_out" == *"$version"* ]] \
  || die "unexpected HyPhy version output: $version_out"

help_out="$(HYPHY_PATH="$pkg/res" "$bin" --help 2>&1 | tr -d '\r')"
[[ "$help_out" == *"HyPhy"* || "$help_out" == *"hyphy"* ]] \
  || die "HyPhy help did not mention HyPhy"

[[ -f "$pkg/res/TemplateBatchFiles/SelectionAnalyses/aBSREL.bf" ]] \
  || die "packaged res/ is missing TemplateBatchFiles/absrel.bf"

mkdir -p "$smoke"
"$pkg/hyphy-run" --version > "$smoke/wrapper.log" 2>&1 \
  || { cat "$smoke/wrapper.log" >&2; die "hyphy-run wrapper failed"; }
grep -q "$version" "$smoke/wrapper.log" \
  || die "hyphy-run did not report the expected version"

log "HyPhy smoke test passed ($version, res/ library present)"
