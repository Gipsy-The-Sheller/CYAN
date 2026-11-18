#!/usr/bin/env bash
#
# Package one staged tool directory into dist/.
#
# Usage: package_tool.sh <tool> <stage-dir>
#
# The archive root is the tool name (for example lsd2/), so extracting a
# package into YR_MPE/bin/ yields YR_MPE/bin/lsd2/<binary> directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

tool="${1:?usage: package_tool.sh <tool> <stage-dir>}"
stage="${2:?usage: package_tool.sh <tool> <stage-dir>}"
tool_dir="$CYAN_ROOT/tools/$tool"

[[ -d "$stage" ]] || die "stage directory does not exist: $stage"
[[ -f "$tool_dir/VERSION" ]] || die "missing $tool_dir/VERSION"

version="$(tr -d '[:space:]' < "$tool_dir/VERSION")"
[[ -n "$version" ]] || die "empty version in $tool_dir/VERSION"

package_dir="$tool"
if [[ -f "$tool_dir/PACKAGE_DIR" ]]; then
  package_dir="$(tr -d '[:space:]' < "$tool_dir/PACKAGE_DIR")"
  [[ -n "$package_dir" ]] || die "empty PACKAGE_DIR in $tool_dir"
fi

upstream_url=""
upstream_commit=""
upstream_tag=""
upstream_license=""
if [[ -f "$tool_dir/UPSTREAM" ]]; then
  upstream_url="$(sed -n 's/^url=//p' "$tool_dir/UPSTREAM" | head -n 1)"
  upstream_commit="$(sed -n 's/^commit=//p' "$tool_dir/UPSTREAM" | head -n 1)"
  upstream_tag="$(sed -n 's/^tag=//p' "$tool_dir/UPSTREAM" | head -n 1)"
  upstream_license="$(sed -n 's/^license=//p' "$tool_dir/UPSTREAM" | head -n 1)"
fi

work_root="$CYAN_BUILD/pkg"
work="$work_root/$package_dir"
rm -rf "$work"
mkdir -p "$work"
cp -a "$stage"/. "$work"/

cat > "$work/SOURCE_MANIFEST.md" <<EOF
# Source manifest

| Field | Value |
| --- | --- |
| Tool | $tool |
| Version | $version |
| Upstream | ${upstream_url:-unknown} |
| Upstream commit | ${upstream_commit:-unknown} |
| Upstream tag | ${upstream_tag:-none} |
| License | ${upstream_license:-see LICENSE} |
| Built from CYAN commit | $CYAN_GIT_SHA |
| Target | $CYAN_PLATFORM_LABEL $CYAN_ARCH |
| Build release | $CYAN_RELEASE |
| Build date | $(date -u +%Y-%m-%dT%H:%M:%SZ) |

The corresponding upstream source is identified by the URL and commit above
and is vendored under \`tools/$tool/\` in the CYAN repository.
EOF

archive_base="${tool}-${version}-${CYAN_PLATFORM_LABEL}-${CYAN_ARCH}-${CYAN_RELEASE}"
rm -f "$CYAN_DIST/$archive_base.zip" \
      "$CYAN_DIST/$archive_base.zip.sha256" \
      "$CYAN_DIST/$archive_base.tar.gz" \
      "$CYAN_DIST/$archive_base.tar.gz.sha256"

cd "$work_root"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  archive="$archive_base.zip"
  zip -qrX "$CYAN_DIST/$archive" "$package_dir"
else
  archive="$archive_base.tar.gz"
  COPYFILE_DISABLE=1 tar -czf "$CYAN_DIST/$archive" "$package_dir"
fi

hash="$(sha256_file "$CYAN_DIST/$archive")"
printf '%s  %s\n' "$hash" "$archive" > "$CYAN_DIST/$archive_base.sha256"

log "Packaged $archive"
log "SHA-256 $hash"
