#!/usr/bin/env bash
#
# Build PhyloBayes-MPI 1.9.
#
# Windows x64 uses the Microsoft MPI SDK (mpi.h + msmpi.lib) with the MSYS2
# MinGW compiler. Linux and macOS use the MPI compiler wrapper (mpicxx).
# Windows arm64 is intentionally unsupported: Microsoft MPI has no ARM64 SDK.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=pbmpi
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
bin="$build/bin"
src="$build/sources"

rm -rf "$build"
mkdir -p "$bin"
cp -a "$TOOL_DIR/sources" "$src"

make_cmd="${MAKE:-}"
if [[ -z "$make_cmd" ]]; then
  if command -v make >/dev/null 2>&1; then
    make_cmd=make
  elif command -v mingw32-make >/dev/null 2>&1; then
    make_cmd=mingw32-make
  else
    die "make not found"
  fi
fi

cppflags="-Wall -O3 -std=c++11"
ldflags="-O3"

if [[ "$CYAN_PLATFORM" == windows ]]; then
  msmpi_inc="$(cyan_msmpi_inc)"
  msmpi_lib="$(cyan_msmpi_lib)"
  [[ -f "$msmpi_inc/mpi.h" ]] \
    || die "MS-MPI SDK mpi.h not found under $msmpi_inc"
  [[ -f "$msmpi_lib/msmpi.lib" ]] \
    || die "MS-MPI SDK msmpi.lib not found under $msmpi_lib"
  cc="$CXX"
  # The include/lib paths contain spaces; keep the quotes inside the make
  # variable so the dependency-generation shell also sees a quoted path.
  cppflags="$cppflags -I\"$msmpi_inc\""
  ldflags="-O3 -L\"$msmpi_lib\" -lmsmpi -static -static-libgcc -static-libstdc++"
  log "MS-MPI SDK: $msmpi_inc"
else
  cc="$(command -v mpicxx || command -v mpic++ || true)"
  [[ -n "$cc" ]] || die "mpicxx not found; install OpenMPI or MPICH"
fi

log "Building $tool $version with $cc"
"$make_cmd" -C "$src" -j"$CYAN_JOBS" \
  PROGSDIR="$bin" \
  CC="$cc" \
  CPPFLAGS="$cppflags" \
  LDFLAGS="$ldflags"

for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  [[ -f "$bin/$prog$CYAN_EXE" ]] \
    || die "build did not produce $bin/$prog$CYAN_EXE"
done

stage="$CYAN_BUILD/stage/$tool"
rm -rf "$stage"
mkdir -p "$stage"
for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  cp "$bin/$prog$CYAN_EXE" "$stage/"
done
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" \
   "$TOOL_DIR/pb_mpiManual1.9.pdf" "$stage/"

if [[ "$CYAN_PLATFORM" == windows ]]; then
  mpiexec="$(cyan_mpiexec)"
  mpi_bin_dir=""
  if [[ -n "$mpiexec" ]]; then
    mpi_bin_dir="$(dirname "$mpiexec")"
    cp "$mpiexec" "$stage/mpiexec.exe"
    cp "$mpiexec" "$stage/mpirun.exe"
  else
    log "warning: mpiexec.exe not found; the package needs an MS-MPI runtime"
  fi
  for name in smpd.exe msmpilaunchsvc.exe; do
    if [[ -n "$mpi_bin_dir" && -f "$mpi_bin_dir/$name" ]]; then
      cp "$mpi_bin_dir/$name" "$stage/"
    fi
  done
  for candidate in \
    "/c/Windows/System32/msmpi.dll" \
    "/c/Windows/SysWOW64/msmpi.dll" \
    "$mpi_bin_dir/msmpi.dll"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      cp "$candidate" "$stage/msmpi.dll"
      break
    fi
  done
  for candidate in \
    "$mpi_bin_dir/../Redist/MSMpiSetup.exe" \
    "/c/Program Files/Microsoft MPI/Redist/MSMpiSetup.exe" \
    "/d/Program Files/Microsoft MPI/Redist/MSMpiSetup.exe"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      cp "$candidate" "$stage/MSMpiSetup.exe"
      break
    fi
  done
  mpi_license="$(cyan_msmpi_license)"
  if [[ -n "$mpi_license" ]]; then
    cp "$mpi_license" "$stage/MicrosoftMPI-Redistributable-EULA.rtf"
  fi
  cat > "$stage/MPI-RUNTIME.txt" <<'EOF'
PhyloBayes-MPI for Windows x64 bundles the Microsoft MPI launcher and
runtime files: mpiexec.exe, mpirun.exe, msmpi.dll, smpd.exe and
msmpilaunchsvc.exe. If Windows refuses the portable launcher, install the
included MSMpiSetup.exe (Microsoft MPI v10.1.1) as administrator.

Native Windows arm64 is not supported: Microsoft MPI publishes only x64
SDK/runtime builds.
EOF
else
  cat > "$stage/MPI-RUNTIME.txt" <<'EOF'
This package bundles an OpenMPI runtime under mpi/ and launcher wrappers.
Use ./mpiexec or ./mpirun. The pb_mpi, readpb_mpi, tracecomp, bpcomp and
cvrep wrappers set OPAL_PREFIX and the library path for the bundled runtime.

If the bundled runtime cannot start on this machine, install OpenMPI/MPICH
and run the corresponding .bin executable with the system mpiexec instead.
EOF
fi

for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$stage/$prog" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$stage/$prog$CYAN_EXE" 2>/dev/null || true
  fi
done

if [[ "$CYAN_PLATFORM" != windows ]]; then
  for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
    mv "$stage/$prog" "$stage/$prog.bin"
  done
  bash "$TOOL_DIR/bundle_mpi.sh" "$stage"
fi

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
