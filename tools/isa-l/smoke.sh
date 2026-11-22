#!/usr/bin/env bash
set -euo pipefail
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOL_DIR/../../scripts/common.sh"
pkg="$CYAN_BUILD/stage/isa-l"
[[ -s "$pkg/lib/libisal.a" ]] || die "missing libisal.a"
[[ -f "$pkg/include/igzip_lib.h" ]] || die "missing igzip_lib.h"
"$AR" t "$pkg/lib/libisal.a" >/dev/null || die "invalid ISA-L archive"
log "ISA-L smoke test passed (static library + headers)"
