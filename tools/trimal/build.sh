#!/usr/bin/env bash
#
# Build trimAl 1.5.1 from the vendored upstream source.
#
# trimAl is a small C++ program with no external dependencies. The upstream
# makefiles build three executables: trimal, readal and statal.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=trimal
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$src"/. "$work"/
rm -f "$work"/*.o "$work"/*.exe "$work"/trimal "$work"/readal "$work"/statal

make_bin="${MAKE:-make}"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  # MSYS2 make strips TMP/TEMP/TMPDIR from the environment, which makes GCC
  # fall back to C:\WINDOWS for temporary files. Pass the Windows paths as
  # make variables so they are exported to the compiler.
  tmpdir="$(cygpath -m "${TMP:-${TEMP:-C:/Windows/Temp}}")"
  "$make_bin" -C "$work" -f makefile.Windows CC="$CXX" \
    TMP="$tmpdir" TEMP="$tmpdir" TMPDIR="$tmpdir" \
    FLAGS="-Wall -O3 -static -static-libgcc -static-libstdc++"
  exe="$CYAN_EXE"
elif [[ "$CYAN_PLATFORM" == macos ]]; then
  "$make_bin" -C "$work" -f makefile.MacOS CC="$CXX" FLAGS="-Wall -O3"
  exe=""
else
  "$make_bin" -C "$work" -f makefile CC="$CXX" FLAGS="-Wall -O3"
  exe=""
fi

mkdir -p "$stage/bin"
for prog in trimal readal statal; do
  [[ -f "$work/$prog$exe" ]] || die "trimAl build did not produce $prog$exe"
  cp "$work/$prog$exe" "$stage/bin/"
  if [[ "$CYAN_PLATFORM" != windows ]]; then
    "$STRIP" --strip-unneeded "$stage/bin/$prog" 2>/dev/null || true
  else
    # Keep the package self-contained; static C++ runtime is requested above.
    :
  fi
done

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
