#!/usr/bin/env bash
#
# Build every tool under tools/<name>/ that provides a build.sh.
#
# CYAN_TOOLS selects a subset, for example:
#   CYAN_TOOLS=lsd2 bash scripts/build_all.sh
#   CYAN_TOOLS="lsd2 mafft" bash scripts/build_all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

scripts="$(cyan_tool_scripts build)" || exit 1
if [[ -z "$scripts" ]]; then
  log "No selected tool supports $CYAN_PLATFORM $CYAN_ARCH; nothing to build"
  exit 0
fi
while IFS= read -r build; do
  [[ -n "$build" ]] || continue
  tool_dir="$(dirname "$build")"
  tool="$(basename "$tool_dir")"
  log "Building $tool ($CYAN_PLATFORM_LABEL $CYAN_ARCH, release $CYAN_RELEASE)"
  (
    cd "$tool_dir"
    bash ./build.sh
  )
done <<< "$scripts"

log "Build complete: $(ls -1 "$CYAN_DIST" | tr '\n' ' ')"
