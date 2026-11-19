#!/usr/bin/env bash
#
# Build Clustal Omega 1.2.4 and its argtable2 dependency from vendored source.
#
# argtable2 2.13 predates modern libc headers; a small patch fixes the
# EOVERFLOW enum clash, old-style getopt prototypes and a missing <ctype.h>.
# Windows and Linux builds are static. OpenMP is enabled where the toolchain
# provides a usable runtime; Windows arm64 and macOS build serial.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=clustalo
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
arg_src="$TOOL_DIR/argtable2"
build="$CYAN_BUILD/$tool"
work="$build/src"
arg_work="$build/argtable2"
arg_build="$build/argtable2-build"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$arg_work" "$stage"
cp -a "$src"/. "$work"/
cp -a "$arg_src"/. "$arg_work"/

# Normalise the patch and the files it changes so CRLF checkouts on Windows
# and LF checkouts on CI both apply cleanly.
arg_patch="$build/argtable2-portability.patch"
tr -d '\r' < "$TOOL_DIR/patches/argtable2-portability.patch" > "$arg_patch"
while IFS= read -r header; do
  file="${header#+++ b/}"
  tr -d '\r' < "$arg_work/$file" > "$arg_work/$file.cyan-tmp"
  mv "$arg_work/$file.cyan-tmp" "$arg_work/$file"
done < <(grep '^+++ b/' "$arg_patch")
patch -p1 -d "$arg_work" --batch < "$arg_patch"

log "Building argtable2 2.13 for $CYAN_PLATFORM $CYAN_ARCH"
cmake -S "$arg_work" -B "$arg_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build "$arg_build" --target argtable2 --parallel "$CYAN_JOBS"

arg_lib="$(find "$arg_build" \( -name 'libargtable2.a' -o -name 'argtable2.lib' \) -print -quit)"
[[ -n "$arg_lib" ]] || die "argtable2 static library not found after the build"

openmp=ON
if [[ "$CYAN_PLATFORM" == macos || "$CYAN_PLATFORM-$CYAN_ARCH" == windows-arm64 ]]; then
  openmp=OFF
fi

log "Configuring Clustal Omega $version ($CYAN_PLATFORM $CYAN_ARCH, OpenMP $openmp)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DENABLE_OPENMP="$openmp"
  -DARGTABLE_INCLUDE_DIR="$arg_work/src"
  -DARGTABLE_LIBRARY_DIR="$(dirname "$arg_lib")"
  -DARGTABLE_LIBRARY="$arg_lib"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
if [[ "$CYAN_PLATFORM" != macos ]]; then
  cmake_args+=(-DCMAKE_EXE_LINKER_FLAGS=-static)
fi
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target clustalo_executable --parallel "$CYAN_JOBS"

bin_path="$cmake_build/src/clustalo$CYAN_EXE"
[[ -f "$bin_path" ]] || die "clustalo binary not found after the build"

cp "$bin_path" "$stage/clustalo$CYAN_EXE"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/LICENSE-argtable2" \
   "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/example.fa"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/clustalo" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/clustalo$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
Clustal Omega $version, built from upstream commit
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

Usage:
  clustalo -i input.fasta -o output.aln --outfmt=fasta --force

The archive root is clustalo/, so extracting it into YR_MPE/bin/ yields
YR_MPE/bin/clustalo/clustalo(.exe).

argtable2 2.13 is vendored and linked statically. Windows and Linux builds
are static. OpenMP is enabled on Windows x64 and Linux; Windows arm64 and
macOS build serial.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
