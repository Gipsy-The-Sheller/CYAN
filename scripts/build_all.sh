#!/usr/bin/env bash
#
# Build every tool under tools/<name>/ that provides a build.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

shopt -s nullglob
builds=("$CYAN_ROOT"/tools/*/build.sh)
if [[ ${#builds[@]} -eq 0 ]]; then
  die "no tools/*/build.sh found"
fi

for build in "${builds[@]}"; do
  tool_dir="$(dirname "$build")"
  tool="$(basename "$tool_dir")"
  log "Building $tool ($CYAN_PLATFORM_LABEL $CYAN_ARCH, release $CYAN_RELEASE)"
  (
    cd "$tool_dir"
    bash ./build.sh
  )
done

log "Build complete: $(ls -1 "$CYAN_DIST" | tr '\n' ' ')"
