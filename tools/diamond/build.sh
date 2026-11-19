#!/usr/bin/env bash
#
# Build DIAMOND 2.2.9.
#
# DIAMOND's CMake build expects zlib and SQLite3. Windows and Linux builds
# are static. The MinGW portability patch fixes POSIX-only file I/O, the
# LLVM/Windows CPUID path, the LLP64 pointer cast in UNLIKELY, and the
# WaitOnAddress import library.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=diamond
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp "$TOOL_DIR/CMakeLists.txt" "$work/"
cp -a "$TOOL_DIR/src" "$work/src"

patch_file="$build/diamond-mingw.patch"
tr -d '\r' < "$TOOL_DIR/patches/diamond-mingw.patch" > "$patch_file"
while IFS= read -r header; do
  file="${header#+++ b/}"
  file="${file%%$'\t'*}"
  [[ -f "$work/$file" ]] || continue
  tr -d '\r' < "$work/$file" > "$work/$file.cyan-tmp"
  mv "$work/$file.cyan-tmp" "$work/$file"
done < <(grep '^+++ b/' "$patch_file")
patch -p1 -d "$work" --batch < "$patch_file"

cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
)
if [[ "$CYAN_PLATFORM" != macos ]]; then
  cmake_args+=(-DBUILD_STATIC=ON -DCMAKE_EXE_LINKER_FLAGS=-static)
fi

log "Configuring DIAMOND $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target diamond --parallel "$CYAN_JOBS"

bin_path="$cmake_build/diamond$CYAN_EXE"
[[ -f "$bin_path" ]] || die "DIAMOND binary not found after the build"

cp "$bin_path" "$stage/diamond$CYAN_EXE"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/diamond" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/diamond$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
DIAMOND $version
================

Built from bbuchfink/diamond tag v2.2.9
($(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8)).

The package root is diamond/, so extracting into YR_MPE/bin/ yields
YR_MPE/bin/diamond/diamond(.exe). OrthoFinder 3 uses DIAMOND by default:

  diamond makedb --in proteins.fa -d proteins
  diamond blastp -d proteins -q query.fa -o hits.tsv

The build uses the upstream CPU dispatcher (generic/SSE4.1/AVX2, or NEON on
ARM64) and does not use -march=native.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
