#!/usr/bin/env bash
#
# Build libdeflate 1.21 as a static library plus the command-line gzip tool.
# The static archive and headers are used by FAMSA and (later) fastp.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=libdeflate
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build" "$stage"
mkdir -p "$work" "$stage/lib" "$stage/include" "$stage/bin"
cp -a "$TOOL_DIR/src"/. "$work"/

log "Configuring libdeflate $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DLIBDEFLATE_BUILD_SHARED_LIB=OFF
  -DLIBDEFLATE_BUILD_STATIC_LIB=ON
  -DLIBDEFLATE_BUILD_GZIP=ON
  -DLIBDEFLATE_BUILD_TESTS=OFF
)
if [[ "$CYAN_PLATFORM" != macos ]]; then
  cmake_args+=(-DCMAKE_EXE_LINKER_FLAGS=-static)
fi
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --parallel "$CYAN_JOBS"

lib_path="$cmake_build/libdeflate.a"
[[ -f "$lib_path" ]] || lib_path="$(find "$cmake_build" -name 'libdeflate.a' | head -n 1)"
[[ -n "$lib_path" && -f "$lib_path" ]] || die "libdeflate static library not found"
cp "$lib_path" "$stage/lib/libdeflate.a"
cp "$work/libdeflate.h" "$stage/include/"

gzip_bin="$(find "$cmake_build" -maxdepth 2 -type f -name "libdeflate-gzip$CYAN_EXE" | head -n 1)"
if [[ -n "$gzip_bin" ]]; then
  cp "$gzip_bin" "$stage/bin/libdeflate-gzip$CYAN_EXE"
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$stage/bin/libdeflate-gzip" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$stage/bin/libdeflate-gzip$CYAN_EXE" 2>/dev/null || true
  fi
fi

cp "$TOOL_DIR/src/COPYING" "$stage/LICENSE"
cp "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
libdeflate $version
===================

Static library and headers for linking into FAMSA and fastp.

  include/libdeflate.h
  lib/libdeflate.a
  bin/libdeflate-gzip(.exe)

The package root is libdeflate/.
Licensed under the MIT license; see LICENSE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
