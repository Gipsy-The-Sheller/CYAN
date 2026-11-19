#!/usr/bin/env bash
#
# Build DecentTree 1.0.0 from the vendored upstream source.
#
# DecentTree implements NJ, BIONJ, RapidNJ, RapidBIONJ and AUCTION. The
# vectorised (vectorclass) implementations are available on x86; on ARM the
# scalar implementations are used and the -V algorithm names are aliased to
# them, so the command line exposed by YR-MPE is the same everywhere.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=decenttree
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
build="$CYAN_BUILD/$tool"
work="$build/src"
cmake_build="$build/cmake-build"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$src"/. "$work"/

# Git checkouts use CRLF on Windows while CI uses LF, and upstream itself
# stores CMakeLists.txt with CRLF. Normalise both the patch and the files it
# touches so patch(1) sees identical line endings on every host.
portability_patch="$build/decenttree-portability.patch"
tr -d '\r' < "$TOOL_DIR/patches/decenttree-portability.patch" \
  > "$portability_patch"
while IFS= read -r header; do
  file="${header#+++ b/}"
  tr -d '\r' < "$work/$file" > "$work/$file.cyan-tmp"
  mv "$work/$file.cyan-tmp" "$work/$file"
done < <(grep '^+++ b/' "$portability_patch")

patch -p1 -d "$work" --batch < "$portability_patch"

# Static linking is supported on Windows and Linux. macOS binaries use the
# system libc++/libSystem and are left dynamic.
dt_flags="no-strip"
if [[ "$CYAN_PLATFORM" == windows || "$CYAN_PLATFORM" == linux ]]; then
  dt_flags="static $dt_flags"
fi

log "Configuring DecentTree $version ($CYAN_PLATFORM $CYAN_ARCH)"
cmake_args=(
  -S "$work"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DDECENTTREE_FLAGS="$dt_flags"
)
cmake "${cmake_args[@]}"
cmake --build "$cmake_build" --target decenttree --parallel "$CYAN_JOBS"

bin_path="$cmake_build/decenttree$CYAN_EXE"
[[ -f "$bin_path" ]] || die "DecentTree binary not found after the build"

cp "$bin_path" "$stage/decenttree$CYAN_EXE"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.mldist" "$stage/example.mldist"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/decenttree" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/decenttree$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
DecentTree $version, built from upstream commit
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

Usage:
  decenttree -in distances.mldist -out tree.nwk -t ALGORITHM -no-banner

Algorithms: NJ, NJ-R, NJ-R-D, NJ-R-V, BIONJ, BIONJ-R, BIONJ-V,
            ONJ-R, ONJ-R-V, AUCTION.

YR-MPE calls BIONJ-R, BIONJ-V, NJ-R-D, ONJ-R, ONJ-R-V and AUCTION.
Trees are written unrooted (the root has three children), which is the
standard representation for distance-based tree construction.

On ARM, the x86-only vectorclass library is not used; NJ-R-V, BIONJ-V and
ONJ-R-V are aliases for the equivalent scalar implementations. On x86 the
vectorised versions are used.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
