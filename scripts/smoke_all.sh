#!/usr/bin/env bash
#
# Run every tool's smoke.sh. The binaries must have been built first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

shopt -s nullglob
smokes=("$CYAN_ROOT"/tools/*/smoke.sh)
if [[ ${#smokes[@]} -eq 0 ]]; then
  die "no tools/*/smoke.sh found"
fi

for smoke in "${smokes[@]}"; do
  tool_dir="$(dirname "$smoke")"
  tool="$(basename "$tool_dir")"
  log "Smoke-testing $tool"
  (
    cd "$tool_dir"
    bash ./smoke.sh
  )
done

log "All smoke tests passed"
