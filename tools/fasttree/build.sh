#!/usr/bin/env bash
#
# Build FastTree 2.2.0.
#
# FastTree is a single C file. CYAN omits upstream's -march=native so the
# binaries run on any CPU of the target architecture. FastTreeMP is built on
# Windows x64 and Linux, where OpenMP can be linked statically; macOS and
# Windows arm64 get the serial FastTree only.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=fasttree
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$build" "$stage"
cp "$TOOL_DIR/src/FastTree.c" "$build/"

common_flags=(-O3 -funsafe-math-optimizations)
case "$CYAN_PLATFORM" in
  windows|linux) common_flags+=(-fopenmp-simd) ;;
esac

link_flags=()
if [[ "$CYAN_PLATFORM" != macos ]]; then
  link_flags+=(-static)
fi

log "Building FastTree $version ($CYAN_PLATFORM $CYAN_ARCH)"
(
  cd "$build"
  "$CC" "${common_flags[@]}" "${link_flags[@]}" \
    -o "FastTree$CYAN_EXE" FastTree.c -lm
)

openmp=OFF
if [[ "$CYAN_PLATFORM" == linux || "$CYAN_PLATFORM-$CYAN_ARCH" == windows-x64 ]]; then
  openmp=ON
  log "Building FastTreeMP (OpenMP)"
  (
    cd "$build"
    "$CC" -DOPENMP -fopenmp "${common_flags[@]}" "${link_flags[@]}" \
      -o "FastTreeMP$CYAN_EXE" FastTree.c -lm
  )
fi

cp "$build/FastTree$CYAN_EXE" "$stage/"
if [[ "$openmp" == ON ]]; then
  cp "$build/FastTreeMP$CYAN_EXE" "$stage/"
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/"

for binary in "$stage/FastTree$CYAN_EXE" "$stage/FastTreeMP$CYAN_EXE"; do
  [[ -f "$binary" ]] || continue
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$binary" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$binary" 2>/dev/null || true
  fi
done

cat > "$stage/README-CYAN.txt" <<EOF
FastTree $version
=================

Built from morgannprice/fasttree commit
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

Binaries:
  FastTree$CYAN_EXE    single-threaded, double precision (2.2 default)
  FastTreeMP$CYAN_EXE  OpenMP build (Windows x64 and Linux only)

The build omits -march=native so the executables are portable across CPUs of
this architecture. FastTreeMP can change the search order and is not
byte-identical to FastTree; set OMP_NUM_THREADS to limit threads.

Examples:
  FastTree -nt alignment.fa > tree.nwk
  FastTree -nt -gamma alignment.fa > tree.nwk
  FastTree alignment.fa > protein_tree.nwk

The package root is FastTree/, so extracting into YR_MPE/bin/ yields
YR_MPE/bin/FastTree/FastTree(.exe), matching YR_MPE/config.json.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
