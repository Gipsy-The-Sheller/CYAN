#!/usr/bin/env bash
#
# Build MPBoot from the vendored upstream source.
#
# MPBoot is an IQ-TREE 1.x-derived maximum-parsimony/bootstrapping program
# with a vendored libpll. The build uses the AVX kernels, matching the CPUs
# YR-MPE targets; the binary prints its own version (1.1.1).

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=mpboot
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$src"/. "$work"/

patch -p1 -d "$work" --batch \
  < "$TOOL_DIR/patches/mpboot-mingw.patch"

log "Configuring MPBoot $version ($CYAN_PLATFORM $CYAN_ARCH, AVX)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DIQTREE_FLAGS=avx
  -DCMAKE_C_FLAGS="-std=gnu99"
)
if [[ "$CYAN_PLATFORM" != windows ]]; then
  cmake_args+=(-DCMAKE_EXE_LINKER_FLAGS=-static)
fi
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target mpboot --parallel "$CYAN_JOBS"

exe="$CYAN_EXE"
bin_path=""
for candidate in \
  "$cmake_build/mpboot-avx$exe" \
  "$cmake_build/mpboot$exe"; do
  if [[ -f "$candidate" ]]; then
    bin_path="$candidate"
    break
  fi
done
[[ -n "$bin_path" ]] || die "MPBoot binary not found after the build"

cp "$bin_path" "$stage/mpboot$exe"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  "$STRIP" --strip-unneeded "$stage/mpboot$exe" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/mpboot" 2>/dev/null || true
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
MPBoot $version, built from upstream branch head
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

The package is an AVX build (-DIQTREE_FLAGS=avx). It requires a CPU with
AVX; all current x86-64 desktop and laptop CPUs provide it. The upstream
binary reports version 1.1.1 even though the upstream release tag is v1.2.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
