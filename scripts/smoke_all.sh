#!/usr/bin/env bash
#
# Run every tool's smoke.sh. The binaries must have been built first.
#
# CYAN_TOOLS selects a subset, matching build_all.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

scripts="$(cyan_tool_scripts smoke)" || exit 1
while IFS= read -r smoke; do
  [[ -n "$smoke" ]] || continue
  tool_dir="$(dirname "$smoke")"
  tool="$(basename "$tool_dir")"
  log "Smoke-testing $tool"
  (
    cd "$tool_dir"
    bash ./smoke.sh
  )
done <<< "$scripts"

log "All smoke tests passed"
