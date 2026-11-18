#!/usr/bin/env bash
#
# Build RAxML-NG 1.2.2 from the vendored upstream source.
#
# Upstream supports Windows only through WSL. The patches add a native
# MinGW system layer and fix libpll/pll-modules portability bugs that also
# affect the Linux/macOS builds only indirectly.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=raxml-ng
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
  < "$TOOL_DIR/patches/raxml-ng-mingw.patch"
patch -p1 -d "$work/libs/pll-modules" --batch \
  < "$TOOL_DIR/patches/pll-modules-portability.patch"
patch -p1 -d "$work/libs/pll-modules/libs/libpll" --batch \
  < "$TOOL_DIR/patches/libpll-portability.patch"

log "Configuring RAxML-NG $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DSTATIC_BUILD=ON
  -DENABLE_RAXML_SIMD=OFF
  -DENABLE_PLLMOD_SIMD=OFF
  -DUSE_MPI=OFF
  -DCMAKE_C_FLAGS="-std=gnu89"
)
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target raxml_module --parallel "$CYAN_JOBS"

exe="$CYAN_EXE"
bin_path=""
for candidate in \
  "$cmake_build/bin/raxml-ng-static$exe" \
  "$cmake_build/bin/raxml-ng$exe"; do
  if [[ -f "$candidate" ]]; then
    bin_path="$candidate"
    break
  fi
done
[[ -n "$bin_path" ]] || die "RAxML-NG binary not found after the build"

mkdir -p "$stage/bin"
cp "$bin_path" "$stage/bin/raxml-ng$exe"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  "$STRIP" --strip-unneeded "$stage/bin/raxml-ng$exe" 2>/dev/null || true
elif [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/bin/raxml-ng" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/bin/raxml-ng" 2>/dev/null || true
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR"/licenses/* "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
RAxML-NG $version, built from the upstream 1.2.2 source with
pll-modules $(
  grep '^pll_modules.commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8
), libpll $(
  grep '^libpll.commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8
) and terraphast $(
  grep '^terraphast.commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8
).

The build includes a native MinGW system layer and portability fixes in
libpll (31-bit RNG shuffle and aligned allocation). RAxML-NG's compile-time
SIMD is disabled so one package runs on every supported CPU; libpll still
selects SSE/AVX kernels at runtime.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
