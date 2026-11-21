#!/usr/bin/env bash
#
# Build HyPhy 2.5.103.
#
# HyPhy's core stores object handles in `long` in a few historical
# containers, which is only valid on LP64 systems. The upstream project has
# no native Windows x64 build, so this package is produced for Linux and
# macOS. Windows users can run the Linux build under WSL2.
#
# Optional BLAS, zlib, curl and MPI support are disabled to keep the package
# self-contained. The standard HyPhy batch library (res/) is shipped, and
# the hyphy-run wrapper points HYPHY_PATH at it.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=hyphy
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

case "$CYAN_PLATFORM" in
  linux|macos) ;;
  *) die "HyPhy is packaged for Linux/macOS only (Windows needs a 64-bit handle port)" ;;
esac

rm -rf "$build"
mkdir -p "$work" "$stage"
cp "$TOOL_DIR/CMakeLists.txt" "$work/"
cp -a "$TOOL_DIR/src" "$work/src"
cp -a "$TOOL_DIR/cmake" "$work/cmake"
# HyPhy's res/ contains filenames with trailing spaces/dots that Windows
# checkouts cannot create; keep the upstream filenames in a tar archive.
tar -xJf "$TOOL_DIR/res.tar.xz" -C "$work"

cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DNOBLAS=ON
  -DNOZLIB=ON
  -DCMAKE_DISABLE_FIND_PACKAGE_BLAS=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_CURL=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_MPI=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_OpenMP=TRUE
)
if [[ "$CYAN_PLATFORM" == linux ]]; then
  cmake_args+=(-DCMAKE_EXE_LINKER_FLAGS=-static)
fi

log "Configuring HyPhy $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target hyphy --parallel "$CYAN_JOBS"

bin_path="$cmake_build/hyphy$CYAN_EXE"
[[ -f "$bin_path" ]] || die "HyPhy binary not found: $bin_path"

cp "$bin_path" "$stage/hyphy$CYAN_EXE"
cp -a "$work/res" "$stage/res"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

cat > "$stage/hyphy-run" <<'EOF'
#!/bin/sh
# Run the packaged HyPhy with its standard batch library.
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HYPHY_PATH="$dir/res" exec "$dir/hyphy" "$@"
EOF
chmod +x "$stage/hyphy-run"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/hyphy" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/hyphy" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
HyPhy $version
==============

Built from veg/hyphy tag 2.5.103
($(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8)).

Programs:
  hyphy        CLI executable
  hyphy-run    wrapper that sets HYPHY_PATH=$PWD/res
  res/         HyPhy standard batch library

Use:
  ./hyphy-run absrel --alignment alignment.fa --tree tree.nwk

HyPhy is built without BLAS, zlib, curl or MPI. The package root is hyphy/.
Native Windows x64 is not supported because HyPhy stores object handles in
C long, which is 32-bit on LLP64; use the Linux build under WSL2 there.
Licensed under the MIT license; see LICENSE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
