#!/usr/bin/env bash
#
# Build LSD2 2.4.4 from the vendored upstream source.
#
# LSD2 is a small C++11 program with no external dependencies; upstream ships
# both a makefile and a CMakeLists.txt. We compile the sources directly so the
# same recipe works in MSYS2, Linux and macOS without a generator dependency.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=lsd2
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
bin="$build/$tool$CYAN_EXE"

rm -rf "$build"
mkdir -p "$build"

cxxflags=(-std=c++11 -O3)
if [[ "$CYAN_PLATFORM" == windows ]]; then
  # Keep the package self-contained: no libgcc/libstdc++/libc++ DLLs.
  case "$(basename "$CXX")" in
    clang++*) cxxflags+=(-static) ;;
    *)        cxxflags+=(-static -static-libgcc -static-libstdc++) ;;
  esac
fi

log "Compiling $tool $version with $CXX"
"$CXX" "${cxxflags[@]}" -o "$bin" "$TOOL_DIR"/src/*.cpp

[[ -f "$bin" ]] || die "compiler did not produce $bin"

version_line="$("$bin" -V 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_line" == *"$version"* ]] \
  || die "unexpected version output: $version_line"

stage="$CYAN_BUILD/stage/$tool"
rm -rf "$stage"
mkdir -p "$stage"
cp "$bin" "$stage/"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"

# The release build has no debug information; strip local symbols when the
# platform tool supports it.
if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/$tool" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/$tool$CYAN_EXE" 2>/dev/null || true
fi

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
