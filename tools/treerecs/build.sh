#!/usr/bin/env bash
#
# Build Treerecs 1.3 from the vendored source tree.
#
# Treerecs bundles Bio++, a Boost subset, pll-modules and libpll. The
# pll-modules submodule is vendored with its libpll submodule populated so the
# build has no network dependency.
#
# Windows and Linux builds are static. OpenMP is enabled on x86-64 and Linux;
# macOS and Windows arm64 build serial.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=treerecs
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

# Normalise the patches and the files they change, so CRLF checkouts on
# Windows and LF checkouts on CI both apply cleanly.
for name in treerecs-cmake pll-modules-errno libpll-pll-export; do
  patch_file="$build/$name.patch"
  tr -d '\r' < "$TOOL_DIR/patches/$name.patch" > "$patch_file"
  while IFS= read -r header; do
    file="${header#+++ b/}"
    tr -d '\r' < "$work/$file" > "$work/$file.cyan-tmp"
    mv "$work/$file.cyan-tmp" "$work/$file"
  done < <(grep '^+++ b/' "$patch_file")
  patch -p1 -d "$work" --batch < "$patch_file"
done

openmp=ON
if [[ "$CYAN_PLATFORM" == macos || "$CYAN_PLATFORM-$CYAN_ARCH" == windows-arm64 ]]; then
  openmp=OFF
fi

log "Configuring Treerecs $version ($CYAN_PLATFORM $CYAN_ARCH, OpenMP $openmp)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DUSE_OMP_IF_FOUND="$openmp"
  -DTREERECS_BUILD_TESTS=OFF
)
if [[ "$CYAN_PLATFORM" != macos ]]; then
  cmake_args+=(-DCMAKE_EXE_LINKER_FLAGS=-static)
fi
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target treerecs --parallel "$CYAN_JOBS"

bin_path="$cmake_build/bin/treerecs$CYAN_EXE"
[[ -f "$bin_path" ]] || die "Treerecs binary not found after the build"

cp "$bin_path" "$stage/treerecs$CYAN_EXE"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/genetree.nwk" "$TOOL_DIR/examples/speciestree.nwk" "$stage/"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/treerecs" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/treerecs$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
Treerecs $version, built from Gipsy-The-Sheller/Treerecs-dev
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

Usage:
  treerecs -g genetree.nwk -s speciestree.nwk -o outdir -O newick

The archive root is treerecs/, so extracting it into YR_MPE/bin/ yields
YR_MPE/bin/treerecs/treerecs(.exe).

The output file is written below the output directory using the gene-tree
file name, for example outdir/genetree.nwk_recs.nwk. Use simple file names
(no directory components) for -g and -s, matching YR-MPE's plugin behavior.

Windows and Linux builds are static. OpenMP is enabled on Windows x64 and
Linux; Windows arm64 and macOS build serial.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
