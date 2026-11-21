#!/usr/bin/env bash
#
# Build FastME 2.1.6.3.
#
# FastME is the distance-based tree builder used by STAG and by
# OrthoFinder's -M dendroblast mode. OpenMP is disabled so the binaries do
# not depend on libomp on macOS/Windows.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=fastme
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

cflags="-O3"
ldflags=""
if [[ "$CYAN_PLATFORM" != macos ]]; then
  ldflags="-static"
fi

log "Configuring FastME $version ($CYAN_PLATFORM $CYAN_ARCH)"
(
  cd "$work"
  ./configure --disable-OpenMP CC="$CC" CFLAGS="$cflags" LDFLAGS="$ldflags"
  make -j "$CYAN_JOBS"
)

bin_path="$work/src/fastme$CYAN_EXE"
[[ -f "$bin_path" ]] || die "FastME binary not found: $bin_path"
cp "$bin_path" "$stage/fastme$CYAN_EXE"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/dist.txt" "$stage/"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/fastme" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/fastme$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
FastME $version
===============

Built from the LIRMM GitLab FastME v2.1.6.3 source tree.

The package root is fastme/, so extracting into YR_MPE/bin/ yields
YR_MPE/bin/fastme/fastme(.exe). OrthoFinder's STAG species-tree method and
-M dendroblast mode invoke this program; YR-MPE can call it directly with:

  fastme -i distance_matrix.txt -o tree.nwk

OpenMP is disabled at build time, so no libomp/libgomp runtime is required.
FastME is distributed under GPL-3.0; see LICENSE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
