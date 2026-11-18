#!/usr/bin/env bash
#
# Build ModelTest-NG 0.1.7 from the vendored upstream source.
#
# Upstream has no native Windows build; the patches add a MinGW/MSVC-compatible
# system layer and fix libpll/pll-modules portability bugs (RAND_MAX is only
# 32767 on Windows, and _aligned_malloc buffers must be freed with
# _aligned_free).

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=modeltest-ng
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$src"/. "$work"/

# Apply the portability patches to the three source repositories.
patch -p1 -d "$work" --batch \
  < "$TOOL_DIR/patches/modeltest-ng-portability.patch"
patch -p1 -d "$work/libs/pll-modules" --batch \
  < "$TOOL_DIR/patches/pll-modules-portability.patch"
patch -p1 -d "$work/libs/pll-modules/libs/libpll" --batch \
  < "$TOOL_DIR/patches/libpll-portability.patch"

log "Configuring ModelTest-NG $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DSTATIC_BUILD=ON
  -DENABLE_MODELTEST_SIMD=OFF
  -DENABLE_PLLMOD_SIMD=OFF
  -DUSE_MPI=OFF
  -DUSE_GUI=OFF
  -DCMAKE_C_FLAGS="-std=gnu89"
)
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target modeltest_module --parallel "$CYAN_JOBS"

# ModelTest writes its executable to <source>/bin, also when the build is
# out-of-source.
exe="$CYAN_EXE"
bin_path=""
for candidate in \
  "$work/bin/modeltest-ng-static$exe" \
  "$work/bin/modeltest-ng$exe" \
  "$cmake_build/bin/modeltest-ng-static$exe" \
  "$cmake_build/bin/modeltest-ng$exe"; do
  if [[ -f "$candidate" ]]; then
    bin_path="$candidate"
    break
  fi
done
[[ -n "$bin_path" ]] || die "ModelTest-NG binary not found after the build"

mkdir -p "$stage/bin"
cp "$bin_path" "$stage/bin/modeltest-ng$exe"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  "$STRIP" --strip-unneeded "$stage/bin/modeltest-ng$exe" 2>/dev/null || true
elif [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/bin/modeltest-ng" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/bin/modeltest-ng" 2>/dev/null || true
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR"/licenses/* "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
ModelTest-NG $version, built from the upstream v0.1.7 source with
pll-modules $(
  grep '^pll_modules.commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8
) and libpll $(
  grep '^libpll.commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8
).

The build includes portability fixes for native Windows (MinGW) and a
race-free Fisher-Yates shuffle in libpll. SIMD remains runtime-dispatched
inside libpll; ModelTest's own compile-time SIMD is disabled so one package
runs on every supported CPU.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
