#!/usr/bin/env bash
set -euo pipefail
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOL_DIR/../../scripts/common.sh"
tool=libdeflate
pkg="$CYAN_BUILD/stage/$tool"
[[ -s "$pkg/lib/libdeflate.a" ]] || die "missing libdeflate.a"
[[ -s "$pkg/include/libdeflate.h" ]] || die "missing libdeflate.h"
"$AR" t "$pkg/lib/libdeflate.a" >/dev/null || die "invalid libdeflate archive"
log "libdeflate smoke test passed (static library + headers)"
