#!/usr/bin/env bash
#
# Build MrBayes 3.2.8 with BEAGLE 4.0.0 on Windows x64 (MSYS2 MINGW64).
#
# MrBayes upstream disables BEAGLE for WIN_VERSION; the patch enables it.
# BEAGLE is built from source with the generic CPU plugin; the SSE plugin is
# skipped because its Windows source has a duplicate check_sse2 definition
# under MinGW. The generic CPU plugin supports BEAGLE_FLAG_THREADING_CPP.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

if [[ "$CYAN_PLATFORM" != windows || "$CYAN_ARCH" != x64 ]]; then
  log "mrbayes: skipping $CYAN_PLATFORM $CYAN_ARCH"
  exit 0
fi

tool=mrbayes
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
beagle_src="$build/beagle-src"
beagle_build="$build/beagle-build"
beagle_prefix="$build/beagle-prefix"
mb_src="$build/mrbayes-src"

rm -rf "$build"
mkdir -p "$build"

# ----------------------------------------------------------------------
# BEAGLE 4.0.0: core library + generic CPU plugin
# ----------------------------------------------------------------------
log "Building BEAGLE 4.0.0"
cp -a "$TOOL_DIR/beagle-lib" "$beagle_src"
(
  cd "$beagle_src"
  patch -p1 --batch < "$TOOL_DIR/patches/beagle-cmake-mingw.patch"
  patch -p1 --batch < "$TOOL_DIR/patches/beagle-winsharedlibrary-mingw.patch"
  patch -p1 --batch < "$TOOL_DIR/patches/beagle-winsharedlibrary-mingw-cpp.patch"
)

cmake -S "$beagle_src" -B "$beagle_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DBUILD_CUDA=OFF -DBUILD_OPENCL=OFF -DBUILD_JNI=OFF
cmake --build "$beagle_build" --target hmsbeagle hmsbeagle-cpu \
  --parallel "$CYAN_JOBS"

core_dll="$(find "$beagle_build" -name 'libhmsbeagle64.dll' | head -n 1)"
cpu_dll="$(find "$beagle_build/libhmsbeagle/CPU" -name 'libhmsbeagle-cpu64-*.dll' | head -n 1)"
import_lib="$(find "$beagle_build" -name 'libhmsbeagle.dll.a' | head -n 1)"
[[ -n "$core_dll" && -f "$core_dll" ]] || die "BEAGLE core DLL not found"
[[ -n "$cpu_dll" && -f "$cpu_dll" ]] || die "BEAGLE CPU plugin DLL not found"
[[ -n "$import_lib" && -f "$import_lib" ]] || die "BEAGLE import library not found"

mkdir -p "$beagle_prefix/include/libhmsbeagle-1/libhmsbeagle" \
         "$beagle_prefix/lib" "$beagle_prefix/bin"
cp "$beagle_src/libhmsbeagle/beagle.h" \
   "$beagle_src/libhmsbeagle/platform.h" \
   "$beagle_prefix/include/libhmsbeagle-1/libhmsbeagle/"
cp "$import_lib" "$beagle_prefix/lib/libhmsbeagle.dll.a"
cp "$core_dll" "$beagle_prefix/bin/libhmsbeagle64.dll"
# The BEAGLE loader asks for hmsbeagle-cpu64-40.dll, without the lib prefix.
cpu_base="$(basename "$cpu_dll")"
cpu_base="${cpu_base#lib}"
cp "$cpu_dll" "$beagle_prefix/bin/$cpu_base"

# ----------------------------------------------------------------------
# MrBayes 3.2.8
# ----------------------------------------------------------------------
log "Building MrBayes $version"
mkdir -p "$mb_src"
for item in src configure configure.ac aclocal.m4 autotools \
            Makefile.am Makefile.in COPYING NEWS README INSTALL examples \
            doc testing; do
  cp -a "$TOOL_DIR/$item" "$mb_src/"
done
(
  cd "$mb_src"
  patch -p1 --batch < "$TOOL_DIR/patches/mrbayes-win-beagle.patch"
  patch -p1 --batch < "$TOOL_DIR/patches/mrbayes-beagle-thread-cap.patch"
  BEAGLE_CFLAGS="-I$beagle_prefix/include/libhmsbeagle-1" \
  BEAGLE_LIBS="-L$beagle_prefix/lib -lhmsbeagle" \
  ./configure --with-beagle="$beagle_prefix" --disable-doc --with-readline=no
)
make -C "$mb_src/src" -j"$CYAN_JOBS"

[[ -f "$mb_src/src/mb.exe" ]] || die "MrBayes did not produce src/mb.exe"

# ----------------------------------------------------------------------
# Stage the package
# ----------------------------------------------------------------------
stage="$CYAN_BUILD/stage/$tool"
rm -rf "$stage"
mkdir -p "$stage"
cp "$mb_src/src/mb.exe" "$stage/"
cp "$beagle_prefix/bin/libhmsbeagle64.dll" "$stage/"
cp "$beagle_prefix/bin/$cpu_base" "$stage/"

mingw_bin="$(dirname "$(command -v "$CC")")"
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll \
           libmcfgthread-2.dll; do
  if [[ -f "$mingw_bin/$dll" ]]; then
    cp "$mingw_bin/$dll" "$stage/"
  fi
done

cp "$TOOL_DIR/COPYING" "$TOOL_DIR/NEWS" "$TOOL_DIR/README" \
   "$TOOL_DIR/VERSION" "$TOOL_DIR/Manual_MrBayes_v3.2.pdf" "$stage/"
cp "$TOOL_DIR/beagle-lib/LICENSE" "$stage/BEAGLE-LICENSE"
cat > "$stage/README-CYAN.txt" <<EOF
MrBayes $version built with BEAGLE 4.0.0 (generic CPU plugin).

BEAGLE CPU threading is enabled by default. "beaglethreadcount=99" (auto)
is capped to the number of physical CPU cores; explicit values above that
are capped as well. To use fewer threads, set it in the mrbayes block:
    set beaglethreadcount=4;

The BEAGLE CPU plugin uses C++11 threading. All runtime DLLs needed by
mb.exe and BEAGLE are included in this directory.
EOF

if command -v "$STRIP" >/dev/null 2>&1; then
  "$STRIP" --strip-unneeded "$stage/mb.exe" 2>/dev/null || true
fi

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
