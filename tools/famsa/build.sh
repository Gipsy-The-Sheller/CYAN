#!/usr/bin/env bash
#
# Build FAMSA 2.5.2.
#
# FAMSA bundles zlib-ng and mimalloc as submodules and uses two libraries that
# CYAN also ships separately: libdeflate on every target, and ISA-L on x86-64.
# We feed it the prebuilt CYAN static archives so the same copy serves FAMSA
# and (later) fastp. zlib-ng is still compiled in-tree because FAMSA expects a
# specific CMake layout for it.
#
# Windows uses the MSYS2/MinGW GCC toolchain. FAMSA cannot be linked with
# STATIC_LINK=true there: the base flags already add -lpthread and the static
# recipe adds it again inside --whole-archive. The three MinGW runtime DLLs
# are packaged next to famsa.exe instead.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=famsa
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

ensure_dep() {
  local name="$1" marker="$2"
  if [[ -f "$marker" ]]; then
    return 0
  fi
  cyan_tool_supported "$CYAN_ROOT/tools/$name" \
    || die "$name is required by $tool but does not support $CYAN_PLATFORM_LABEL $CYAN_ARCH"
  log "Building dependency $name for $tool"
  (
    cd "$CYAN_ROOT/tools/$name"
    bash ./build.sh
  )
}

libdeflate_stage="$CYAN_BUILD/stage/libdeflate"
ensure_dep libdeflate "$libdeflate_stage/lib/libdeflate.a"

isa_l_stage="$CYAN_BUILD/stage/isa-l"
if [[ "$CYAN_ARCH" == x64 ]]; then
  ensure_dep isa-l "$isa_l_stage/lib/libisal.a"
fi

rm -rf "$build" "$stage"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

# Git checkouts on Windows may use CRLF; patch hunks are LF.
for f in makefile refresh.mk src/utils/timer.h src/utils/timer.cpp \
         libs/refresh/active_thread_pool/lib/utils.h; do
  if grep -q $'\r' "$work/$f"; then
    tr -d '\r' < "$work/$f" > "$work/$f.lf"
    mv "$work/$f.lf" "$work/$f"
  fi
done

log "Applying FAMSA portability patch"
(
  cd "$work"
  patch -p1 --batch --forward < "$TOOL_DIR/patches/famsa-mingw.patch"
)

# Place the prebuilt CYAN archives in the layout FAMSA's refresh.mk expects.
mkdir -p "$work/libs/libdeflate/build"
cp "$libdeflate_stage/include/libdeflate.h" "$work/libs/libdeflate/"
cp "$libdeflate_stage/lib/libdeflate.a" "$work/libs/libdeflate/build/"

if [[ "$CYAN_ARCH" == x64 ]]; then
  mkdir -p "$work/libs/isa-l/bin" "$work/libs/isa-l/include"
  cp "$isa_l_stage/lib/libisal.a" "$work/libs/isa-l/bin/isa-l.a"
  cp -a "$isa_l_stage/include"/. "$work/libs/isa-l/include/"
fi

platform=
static_link=false
case "$CYAN_PLATFORM-$CYAN_ARCH" in
  windows-x64|linux-x64) platform=avx2 ;;
  linux-arm64) platform=arm8 ;;
  *) die "unsupported FAMSA target: $CYAN_PLATFORM $CYAN_ARCH" ;;
esac
if [[ "$CYAN_PLATFORM" == linux ]]; then
  static_link=true
fi

log "Building FAMSA $version ($CYAN_PLATFORM $CYAN_ARCH, platform=$platform)"
(
  cd "$work"
  make -j "$CYAN_JOBS" \
    PLATFORM="$platform" \
    STATIC_LINK="$static_link" \
    CXX="$CXX" CC="$CC" AR="$AR"
)

binary="$work/bin/famsa$CYAN_EXE"
[[ -f "$binary" ]] || die "FAMSA binary not found: $binary"
cp "$binary" "$stage/"

if [[ "$CYAN_PLATFORM" == windows ]]; then
  # FAMSA is linked against the MSYS2 MinGW runtime; ship the DLLs it imports.
  mingw_bin="$(dirname "$(command -v "$CXX")")"
  for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
    [[ -f "$mingw_bin/$dll" ]] || die "missing MinGW runtime DLL: $mingw_bin/$dll"
    cp "$mingw_bin/$dll" "$stage/"
  done
fi

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/"

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/famsa$CYAN_EXE" 2>/dev/null || true
else
  "$STRIP" --strip-unneeded "$stage/famsa$CYAN_EXE" 2>/dev/null || true
fi

cat > "$stage/README-CYAN.txt" <<EOF
FAMSA $version
==============

Built from refresh-bio/FAMSA tag v2.5.2 with the CYAN portability patch.
Compression back ends: ISA-L (x86-64) or zlib-ng (ARM), plus libdeflate.
Those libraries are CYAN packages of their own; zlib-ng and mimalloc are
compiled from the sources vendored with FAMSA.

Binary:
  famsa$CYAN_EXE

Windows also ships libgcc_s_seh-1.dll, libstdc++-6.dll and
libwinpthread-1.dll; keep them beside famsa.exe.

Examples:
  famsa -t 8 proteins.fasta aligned.fasta
  famsa -t 8 -gt upgma proteins.fasta aligned.fasta
  famsa -t 8 -gt_export proteins.fasta guide.nwk

The package root is famsa/, so extracting into YR_MPE/bin/ yields
YR_MPE/bin/famsa/famsa(.exe).
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
