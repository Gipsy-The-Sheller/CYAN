#!/usr/bin/env bash
#
# Build ASTER v1.25 (ASTRAL-IV, ASTRAL-Pro3, wASTRAL, CASTER and the
# distance-based utilities). CYAN deliberately does not use the upstream
# makefile's -march=native flags.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=aster
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

patch_file="$build/aster-int128-rng.patch"
tr -d '\r' < "$TOOL_DIR/patches/aster-int128-rng.patch" > "$patch_file"
tr -d '\r' < "$work/algorithms.hpp" > "$work/algorithms.hpp.tmp"
mv "$work/algorithms.hpp.tmp" "$work/algorithms.hpp"
patch -p1 -d "$build" --batch < "$patch_file"

cxxflags=(-std=c++17 -O2 -pthread)
linkflags=()
if [[ "$CYAN_PLATFORM" != macos ]]; then
  linkflags=(-static -static-libgcc -static-libstdc++)
fi

build_target() {
  local out="$1" src="$2"
  log "Building $out"
  "$CXX" "${cxxflags[@]}" "${linkflags[@]}" "$work/$src" -o "$stage/$out$CYAN_EXE"
}

build_target astral4 astral.cpp
cp "$stage/astral4$CYAN_EXE" "$stage/astral$CYAN_EXE"

build_target astral-pro3 astral-pro.cpp
cp "$stage/astral-pro3$CYAN_EXE" "$stage/astral-pro$CYAN_EXE"

build_target wastral astral-hybrid.cpp
cp "$stage/wastral$CYAN_EXE" "$stage/astral-hybrid$CYAN_EXE"

build_target caster-site caster-site.cpp
build_target caster-pair caster-pair.cpp
build_target waster waster.cpp
build_target dstar dstar.cpp
build_target dstar-branch dstar-branch.cpp
build_target sister sister.cpp

for bin in "$stage"/*"$CYAN_EXE"; do
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$bin" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$bin" 2>/dev/null || true
  fi
done

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/tiny.trees" "$TOOL_DIR/examples/tiny.map" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
ASTER $version
==============

Built from chaoszhang/ASTER tag v1.25.

Programs:
  astral4 / astral            ASTRAL-IV
  astral-pro3 / astral-pro    ASTRAL-Pro3 (multi-copy gene trees)
  wastral / astral-hybrid     wASTRAL
  caster-site, caster-pair    CASTER
  waster, dstar, dstar-branch, sister

ASTRAL-Pro3 example:
  astral-pro3 -i tiny.trees -o species.tree -t 1

The build omits -march=native and uses -O2 with static libgcc/libstdc++ on
Windows and Linux. The package root is aster/, so extracting into
YR_MPE/bin/ yields YR_MPE/bin/aster/astral4(.exe), matching the old
YR-MPE ASTER directory layout.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
