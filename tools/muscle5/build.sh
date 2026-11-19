#!/usr/bin/env bash
#
# Build MUSCLE 5.3 from the vendored upstream source.
#
# MUSCLE is built from the same file list as the upstream Visual Studio
# project, but with GCC/Clang everywhere. Upstream HEAD (after v5.3) contains
# the mingw-w64 and aarch64 fixes needed for these builds. MUSCLE requires
# OpenMP; Windows/Linux binaries link the runtime statically, and the macOS
# package bundles Homebrew's libomp.dylib.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=muscle5
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
upstream_commit="$(sed -n 's/^commit=//p' "$TOOL_DIR/UPSTREAM" | head -n 1)"
short_commit="${upstream_commit:0:7}"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/
printf '"%s"\n' "$short_commit" > "$work/src/gitver.txt"

cd "$work/src"
grep '<ClCompile Include' muscle.vcxproj \
  | sed 's/.*Include="//;s/\.cpp".*//' > sources.txt
source_count="$(wc -l < sources.txt)"
[[ "$source_count" -gt 100 ]] || die "unexpected MUSCLE source count: $source_count"
mkdir -p obj

cxxflags=(-std=gnu++17 -O3 -DNDEBUG -ffast-math -pthread -I.)
link_flags=(-pthread)
if [[ "$CYAN_PLATFORM" == windows ]]; then
  cxxflags+=(-DWIN32 -D_WIN32_WINNT=0x0601 -fopenmp)
  link_flags+=(-fopenmp -static -static-libgcc -static-libstdc++)
elif [[ "$CYAN_PLATFORM" == linux ]]; then
  cxxflags+=(-fopenmp)
  link_flags+=(-fopenmp -static)
else
  omp_prefix="$(brew --prefix libomp 2>/dev/null || true)"
  [[ -n "$omp_prefix" ]] || die "Homebrew libomp is required on macOS"
  cxxflags+=(-Xpreprocessor -fopenmp -I"$omp_prefix/include")
  link_flags+=(-L"$omp_prefix/lib" -lomp)
fi

export MUSCLE_CXX="$CXX"
export MUSCLE_CXXFLAGS="${cxxflags[*]}"
log "Compiling MUSCLE $version ($CYAN_PLATFORM $CYAN_ARCH, $source_count sources)"
if ! cat sources.txt | xargs -P "$CYAN_JOBS" -n1 bash -c '
    f="$1"
    "$MUSCLE_CXX" $MUSCLE_CXXFLAGS -c "$f.cpp" -o "obj/$f.o" || {
      echo "FAILED $f" >&2
      exit 1
    }
  ' _ > "$build/compile.log" 2>&1; then
  grep -n -m20 'error:\|FAILED' "$build/compile.log" >&2 || true
  die "MUSCLE compilation failed (see $build/compile.log)"
fi

"$CXX" "${link_flags[@]}" obj/*.o -o "$stage/muscle$CYAN_EXE"

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/example.fa"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  omp_dylib="$omp_prefix/lib/libomp.dylib"
  [[ -f "$omp_dylib" ]] || die "libomp.dylib not found under $omp_prefix/lib"
  cp "$omp_dylib" "$stage/libomp.dylib"
  while IFS= read -r dep; do
    install_name_tool -change "$dep" "@loader_path/libomp.dylib" \
      "$stage/muscle" 2>/dev/null || true
  done < <(otool -L "$stage/muscle" | awk '/libomp/ {print $1}')
  codesign --force --sign - "$stage/libomp.dylib" >/dev/null 2>&1 || true
  "$STRIP" -x "$stage/muscle" 2>/dev/null || true
  codesign --force --sign - "$stage/muscle" >/dev/null 2>&1 || true
else
  "$STRIP" --strip-unneeded "$stage/muscle$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
MUSCLE $version, built from upstream commit
${upstream_commit:0:8} (post-v5.3 HEAD with mingw-w64 and aarch64 fixes).

Usage:
  muscle -align input.fasta -output output.fasta

The archive root is muscle5/, so extracting it into YR_MPE/bin/ yields
YR_MPE/bin/muscle5/muscle(.exe).

Windows and Linux binaries are static, including the OpenMP runtime. The
macOS package bundles libomp.dylib next to the binary and loads it through
@loader_path, so Homebrew is not required at run time.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
