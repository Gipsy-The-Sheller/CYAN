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
  patch -p1 --batch < "$TOOL_DIR/patches/beagle-cpusse-neon.patch"
)

cmake_cxx_flags=""
if [[ "$CYAN_ARCH" == x64 ]]; then
  cmake_cxx_flags="-msse4.2"
fi
cmake -S "$beagle_src" -B "$beagle_build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_CXX_FLAGS="$cmake_cxx_flags" \
  -DBUILD_CUDA=OFF -DBUILD_OPENCL=OFF -DBUILD_JNI=OFF
cmake --build "$beagle_build" --target hmsbeagle hmsbeagle-cpu hmsbeagle-cpu-sse \
  --parallel "$CYAN_JOBS"

core_dll="$(find "$beagle_build" -name 'libhmsbeagle64.dll' | head -n 1)"
cpu_dll="$(find "$beagle_build/libhmsbeagle/CPU" -name 'libhmsbeagle-cpu64-*.dll' | head -n 1)"
sse_dll="$(find "$beagle_build/libhmsbeagle/CPU" -name 'libhmsbeagle-cpu-sse64-*.dll' | head -n 1)"
import_lib="$(find "$beagle_build" -name 'libhmsbeagle.dll.a' | head -n 1)"
[[ -n "$core_dll" && -f "$core_dll" ]] || die "BEAGLE core DLL not found"
[[ -n "$cpu_dll" && -f "$cpu_dll" ]] || die "BEAGLE CPU plugin DLL not found"
[[ -n "$sse_dll" && -f "$sse_dll" ]] || die "BEAGLE SSE plugin DLL not found"
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
sse_base="$(basename "$sse_dll")"
sse_base="${sse_base#lib}"
cp "$sse_dll" "$beagle_prefix/bin/$sse_base"

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
# MS-MPI is exposed through a small mpicc wrapper: MS-MPI ships mpi.h and
# msmpi.lib but no compiler wrapper. The wrapper makes AX_PROG_CC_MPI's
# MPI_Init and mpi.h checks succeed.
msmpi_inc="$(cyan_msmpi_inc)"
msmpi_lib="$(cyan_msmpi_lib)"
[[ -f "$msmpi_inc/mpi.h" ]] || die "MS-MPI SDK mpi.h not found under $msmpi_inc"
[[ -f "$msmpi_lib/msmpi.lib" ]] || die "MS-MPI SDK msmpi.lib not found under $msmpi_lib"
mpi_wrap="$build/mpi-wrapper"
mkdir -p "$mpi_wrap"
{
  printf '#!/bin/sh\n'
  printf 'exec "%s" -I"%s" "$@" -L"%s" -lmsmpi\n' "$CC" "$msmpi_inc" "$msmpi_lib"
} > "$mpi_wrap/mpicc"
chmod +x "$mpi_wrap/mpicc"

(
  cd "$mb_src"
  patch -p1 --batch < "$TOOL_DIR/patches/mrbayes-win-beagle.patch"
  patch -p1 --batch < "$TOOL_DIR/patches/mrbayes-beagle-thread-cap.patch"
  CC="$mpi_wrap/mpicc" MPICC="$mpi_wrap/mpicc" \
  BEAGLE_CFLAGS="-I$beagle_prefix/include/libhmsbeagle-1" \
  BEAGLE_LIBS="-L$beagle_prefix/lib -lhmsbeagle" \
  ./configure --with-mpi --with-beagle="$beagle_prefix" --disable-doc \
              --disable-dependency-tracking --with-readline=no
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
cp "$beagle_prefix/bin/$sse_base" "$stage/"

# MS-MPI launcher and runtime files. mpiexec.exe is included so the package
# can run multi-instance chains; MSMpiSetup.exe is the fallback installer.
mpiexec="$(cyan_mpiexec)"
if [[ -n "$mpiexec" ]]; then
  mpi_bin_dir="$(dirname "$mpiexec")"
  cp "$mpiexec" "$stage/mpiexec.exe"
  cp "$mpiexec" "$stage/mpirun.exe"
  for name in smpd.exe msmpilaunchsvc.exe; do
    [[ -f "$mpi_bin_dir/$name" ]] && cp "$mpi_bin_dir/$name" "$stage/"
  done
  for dll in msmpi.dll msmpires.dll; do
    for candidate in "/c/Windows/System32/$dll" "$mpi_bin_dir/$dll"; do
      if [[ -f "$candidate" ]]; then
        cp "$candidate" "$stage/$dll"
        break
      fi
    done
  done
  for candidate in \
    "$mpi_bin_dir/../Redist/MSMpiSetup.exe" \
    "/c/Program Files/Microsoft MPI/Redist/MSMpiSetup.exe" \
    "/d/Program Files/Microsoft MPI/Redist/MSMpiSetup.exe"; do
    if [[ -f "$candidate" ]]; then
      cp "$candidate" "$stage/MSMpiSetup.exe"
      break
    fi
  done
  mpi_license="$(cyan_msmpi_license)"
  [[ -n "$mpi_license" ]] && cp "$mpi_license" "$stage/MicrosoftMPI-Redistributable-EULA.rtf"
else
  log "warning: mpiexec.exe not found; MPI runtime is not bundled"
fi

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
MrBayes $version built with BEAGLE 4.0.0 (generic CPU and SSE/NEON plugins)
and Microsoft MPI (MS-MPI).

Multi-instance runs use the bundled MS-MPI launcher:
    mpiexec -n 4 mb.exe input.nex

BEAGLE CPU threading is enabled by default. "beaglethreadcount=99" (auto)
is capped to the number of physical CPU cores; explicit values above that
are capped as well. To use fewer threads, set it in the mrbayes block:
    set beaglethreadcount=4;

The BEAGLE CPU and SSE plugins use C++11 threading; the SSE plugin maps
SSE2 intrinsics to NEON on ARM64. All runtime DLLs needed by mb.exe, BEAGLE
and MS-MPI are included. If Windows refuses the portable launcher, install
MSMpiSetup.exe as administrator.
EOF

if command -v "$STRIP" >/dev/null 2>&1; then
  "$STRIP" --strip-unneeded "$stage/mb.exe" 2>/dev/null || true
fi

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
