#!/usr/bin/env bash
#
# Build Intel ISA-L 2.30.0 as a static library.
#
# ISA-L is x86-64 only; ARM builds use zlib-ng instead. The library is
# shared by FAMSA and (later) fastp.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=isa-l
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

[[ "$CYAN_ARCH" == x64 ]] || die "ISA-L is x86-64 only"
command -v nasm >/dev/null 2>&1 || die "nasm is required for ISA-L"

rm -rf "$build" "$stage"
mkdir -p "$work" "$stage/lib" "$stage/include"
cp -a "$TOOL_DIR/src"/. "$work"/
# NASM macro continuations must not see CRLF line endings on Windows.
find "$work" -type f \( -name '*.asm' -o -name '*.inc' -o -name 'Makefile*' -o -name '*.am' -o -name '*.mk' \)   -exec sh "$TOOL_DIR/normalize-crlf.sh" {} +

log "Building ISA-L $version ($CYAN_PLATFORM $CYAN_ARCH)"
(
  cd "$work"
  if [[ "$CYAN_PLATFORM" == windows ]]; then
    # The default target also attempts a shared library, which MSYS ld
    # cannot link; the static archive is produced first.
    make -f Makefile.unx -j "$CYAN_JOBS" arch=mingw       CC="$CC" AR="$AR" AS=nasm || true
  else
    make -f Makefile.unx -j "$CYAN_JOBS" CC="$CC" AR="$AR" AS=nasm
  fi
)

lib="$work/bin/isa-l.a"
[[ -f "$lib" ]] || die "ISA-L static library not found: $lib"
cp "$lib" "$stage/lib/libisal.a"
cp -a "$work/include"/. "$stage/include/"
if [[ -f "$work/LICENSE" ]]; then
  cp "$work/LICENSE" "$stage/LICENSE"
elif [[ -f "$TOOL_DIR/LICENSE" ]]; then
  cp "$TOOL_DIR/LICENSE" "$stage/LICENSE"
fi
cp "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

cat > "$stage/README-CYAN.txt" <<'EOF'
ISA-L 2.30.0
============

Static x86-64 library and headers for linking into FAMSA and fastp.

  include/
  lib/libisal.a

The package root is isa-l/.
Licensed under BSD-3-Clause; see LICENSE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
