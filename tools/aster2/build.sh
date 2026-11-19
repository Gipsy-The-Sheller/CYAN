#!/usr/bin/env bash
#
# Build ASTER2 from the vendored upstream source.
#
# ASTER2 is the C++20 successor to ASTER. This package ships the two stable
# entry points used by YR-MPE: astral (ASTRAL-IV/wASTRAL) and caster
# (CASTER-site). The experimental fasta2ref tools (trial/wtrial/wcaster) are
# not packaged; their Windows temporary-file handling is not usable from the
# YR-MPE plugin yet.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=aster2
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

portability_patch="$build/aster2-portability.patch"
tr -d '\r' < "$TOOL_DIR/patches/aster2-portability.patch" > "$portability_patch"
while IFS= read -r header; do
  file="${header#+++ b/}"
  tr -d '\r' < "$work/$file" > "$work/$file.cyan-tmp"
  mv "$work/$file.cyan-tmp" "$work/$file"
done < <(grep '^+++ b/' "$portability_patch")
patch -p1 -d "$work" --batch < "$portability_patch"

cxxflags=(-std=c++20 -O2 -pthread)
link_flags=(-pthread)
if [[ "$CYAN_PLATFORM" == windows ]]; then
  link_flags+=(-static -static-libgcc -static-libstdc++)
elif [[ "$CYAN_PLATFORM" == linux ]]; then
  link_flags+=(-static)
fi

for pair in "ASTRAL:astral" "CASTER:caster"; do
  define="${pair%%:*}"
  name="${pair##*:}"
  log "Compiling ASTER2 $name ($CYAN_PLATFORM $CYAN_ARCH)"
  "$CXX" "${cxxflags[@]}" -D "$define" "$work/src/driver.cpp" \
    -o "$stage/$name$CYAN_EXE" "${link_flags[@]}"
done

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" \
   "$TOOL_DIR/examples/tiny.trees" "$TOOL_DIR/examples/tiny.phy" "$stage/"

for name in astral caster; do
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$stage/$name" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$stage/$name$CYAN_EXE" 2>/dev/null || true
  fi
done

cat > "$stage/README-CYAN.txt" <<EOF
ASTER2 $version (pre-release), built from upstream commit
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8).

ASTER2 is alpha software: command-line options and output annotations may
change between upstream commits. This package contains the two tools used by
YR-MPE:

  astral -i gene_trees.nw -o species_tree.nw -t 1 -u none -l none --no-log
  caster -i alignment.phy -o species_tree.nw -t 1 -u none -l none --no-log

astral replaces ASTER's astral4/wastral/astral-hybrid entry points and uses
--mode to select the weighting scheme. caster implements CASTER-site. The
experimental trial/wtrial/wcaster tools are not packaged.

The archive root is aster2/, so extracting it into YR_MPE/bin/ yields
YR_MPE/bin/aster2/astral(.exe) and caster(.exe).

Windows and Linux binaries are static; the macOS binary uses the system
libc++/libSystem. No external libraries are required.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
