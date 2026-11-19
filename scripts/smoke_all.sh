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
if [[ -z "$scripts" ]]; then
  log "No selected tool supports $CYAN_PLATFORM $CYAN_ARCH; nothing to smoke-test"
  exit 0
fi
while IFS= read -r smoke; do
  [[ -n "$smoke" ]] || continue
  tool_dir="$(dirname "$smoke")"
  tool="$(basename "$tool_dir")"
  log "Smoke-testing $tool"
  (
    cd "$tool_dir"
    # Detach the smoke test from the here-string that lists the remaining
    # tools. Some programs (notably MPI launchers) otherwise consume it and
    # silently end the loop after their own test.
    bash ./smoke.sh < /dev/null
  )
done <<< "$scripts"

log "All smoke tests passed"
