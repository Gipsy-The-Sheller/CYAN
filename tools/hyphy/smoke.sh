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
if [[ "$CYAN_PLATFORM" == windows ]]; then
  [[ -f "$pkg/hyphy-run.bat" ]] || die "missing hyphy-run.bat wrapper"
else
  [[ -x "$pkg/hyphy-run" ]] || die "missing hyphy-run wrapper"
fi
[[ -d "$pkg/res" ]] || die "missing HyPhy res/ library"

set +e
version_raw="$(HYPHY_PATH="$pkg/res" "$bin" --version 2>&1)"
version_rc=$?
set -e
version_out="$(printf '%s\n' "$version_raw" | tr -d '\r' | head -n 3)"
[[ "$version_rc" -eq 0 ]] \
  || die "hyphy --version exited $version_rc: $version_raw"
[[ "$version_out" == *"$version"* ]] \
  || die "unexpected HyPhy version output: $version_out"

set +e
help_out="$(HYPHY_PATH="$pkg/res" "$bin" --help 2>&1)"
help_rc=$?
set -e
help_out="$(printf '%s\n' "$help_out" | tr -d '\r')"
[[ "$help_rc" -eq 0 ]] || die "hyphy --help exited $help_rc: $help_out"
[[ "$help_out" == *"HyPhy"* || "$help_out" == *"hyphy"* ]] \
  || die "HyPhy help did not mention HyPhy"

[[ -f "$pkg/res/TemplateBatchFiles/SelectionAnalyses/aBSREL.bf" ]] \
  || die "packaged res/ is missing TemplateBatchFiles/absrel.bf"

mkdir -p "$smoke"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  ( cd "$pkg" && /c/Windows/System32/cmd.exe //c ".\\hyphy-run.bat --version" ) \
    > "$smoke/wrapper.log" 2>&1 \
    || { cat "$smoke/wrapper.log" >&2; die "hyphy-run.bat wrapper failed"; }
else
  "$pkg/hyphy-run" --version > "$smoke/wrapper.log" 2>&1 \
    || { cat "$smoke/wrapper.log" >&2; die "hyphy-run wrapper failed"; }
fi
grep -q "$version" "$smoke/wrapper.log" \
  || die "hyphy-run did not report the expected version"

# Exercise the packaged batch library, not just the executable.
if [[ "$CYAN_PLATFORM" == windows ]]; then
  ( cd "$pkg" && /c/Windows/System32/cmd.exe //c ".\\hyphy-run.bat absrel --help" ) \
    > "$smoke/absrel.log" 2>&1
else
  "$pkg/hyphy-run" absrel --help > "$smoke/absrel.log" 2>&1
fi
grep -q 'Available analysis command line options' "$smoke/absrel.log" \
  || die "HyPhy could not load the aBSREL batch file"

log "HyPhy smoke test passed ($version, res/ library present)"
