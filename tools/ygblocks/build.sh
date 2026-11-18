#!/usr/bin/env bash
#
# Build YGBlocks, an independent GBlocks 0.91b-compatible block selector.
#
# The binary is named Gblocks so the package can be dropped into
# YR_MPE/bin/Gblocks/ directly.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=ygblocks
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src/ygblocks.cpp"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$stage"
mkdir -p "$stage/bin"

cxxflags=(-std=c++17 -O2 -Wall -Wextra)
if [[ "$CYAN_PLATFORM" == windows ]]; then
  cxxflags+=(-static -static-libgcc -static-libstdc++)
elif [[ "$CYAN_PLATFORM" == linux ]]; then
  cxxflags+=(-static)
fi

log "Building YGBlocks $version ($CYAN_PLATFORM $CYAN_ARCH)"
"$CXX" "${cxxflags[@]}" -o "$stage/bin/Gblocks$CYAN_EXE" "$src"

if [[ "$CYAN_PLATFORM" == windows ]]; then
  "$STRIP" --strip-unneeded "$stage/bin/Gblocks$CYAN_EXE" 2>/dev/null || true
elif [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/bin/Gblocks" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/bin/Gblocks" 2>/dev/null || true
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
YGBlocks $version: an independent, MIT-licensed implementation of the
GBlocks 0.91b conserved-block selection.

Input: FASTA or PHYLIP (interleaved or one-line sequential).
Selected alignment: <input><ext>.fa (FASTA).
Report:             <input><ext>.txt (masked interleaved PHYLIP; removed
                    positions are lowercase and '-' is written as '.').

The selected-block output is byte-compatible with GBlocks for nucleotide,
codon and protein alignments. Protein similarity uses the Gonnet 120 matrix.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
