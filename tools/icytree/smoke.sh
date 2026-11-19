#!/usr/bin/env bash
#
# Smoke-test the static IcyTree package.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=icytree
pkg="$CYAN_BUILD/stage/$tool"
index="$pkg/index.html"

[[ -f "$index" ]] || die "missing packaged index.html"
grep -q 'IcyTree' "$index" || die "index.html does not look like IcyTree"
[[ -s "$pkg/js/libs/plotly.js" ]] || die "missing bundled plotly.js"
[[ -s "$pkg/js/icytree.js" ]] || die "missing icytree.js"
[[ -s "$pkg/css/icytree.css" ]] || die "missing icytree.css"
[[ -s "$pkg/jquery-ui/jquery-ui.js" ]] || die "missing jQuery UI"
[[ -s "$pkg/images/icytree.ico" ]] || die "missing IcyTree icon"
[[ -s "$pkg/LICENSE" ]] || die "missing GPL license"

# Every local asset referenced by index.html must be present. External links,
# anchors and data: URLs are skipped.
missing=0
while IFS= read -r ref; do
  [[ -n "$ref" ]] || continue
  case "$ref" in
    http://*|https://*|mailto:*|javascript:*|data:*|\#*) continue ;;
  esac
  if [[ ! -f "$pkg/$ref" ]]; then
    log_err "missing IcyTree asset: $ref"
    missing=1
  fi
done < <(
  grep -oE '(src|href)="[^"]+"' "$index" \
    | sed 's/^[^=]*="//; s/"$//' \
    | sort -u
)
[[ "$missing" == 0 ]] || die "index.html references missing assets"

size="$(wc -c < "$pkg/js/libs/plotly.js")"
[[ "$size" -gt 5000000 ]] || die "plotly.js looks truncated ($size bytes)"

log "IcyTree smoke test passed (static HTML, $(du -sh "$pkg" | cut -f1))"
