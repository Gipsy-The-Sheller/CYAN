#!/usr/bin/env bash
#
# Build IQ-TREE 3.0.1 from the vendored upstream source.
#
# Windows uses Clang on purpose. IQ-TREE's CMake adds "novx" for GCC on
# Windows ("GCC does not properly support memory alignment"), which caps the
# runtime at SSE4.2 and removes the AVX/FMA kernels. The official Windows
# binaries are Clang builds; using Clang here keeps the AVX+FMA kernel.
#
# The Windows build also enables "cpp14" because the upstream Windows recipe
# does so for the MinGW toolchain. CMAPLE is disabled on Windows upstream.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=iqtree3
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
src="$TOOL_DIR/src"
build="$CYAN_BUILD/$tool"
cmake_build="$build/cmake"
stage="$CYAN_BUILD/stage/$tool"

[[ -f "$src/CMakeLists.txt" ]] || die "missing vendored IQ-TREE source: $src"
[[ -f "$src/cmaple/CMakeLists.txt" ]] || die "missing vendored CMAPLE source"
[[ -f "$src/lsd2/CMakeLists.txt" ]] || die "missing vendored LSD2 source"

rm -rf "$build"
mkdir -p "$cmake_build" "$stage"

# MinGW/Clang needs two small fixes for IQ-TREE 3.0.1:
#   * pll/hardware.c calls the MSVC __cpuid intrinsic whenever WIN32 is
#     defined; route non-MSVC builds through the existing inline-asm path.
#   * terraphast pins CXX_STANDARD 11; Clang 23 rejects the checked_uint
#     operator definitions in C++11/14 mode (duplicate mangled names).
#     Use C++17 for terraphast when building with Clang on Windows.
# Apply the patch to a build copy to keep the vendored upstream tree pristine.
if [[ "$CYAN_PLATFORM" == windows ]]; then
  src="$build/src"
  cp -a "$TOOL_DIR/src" "$src"
  (
    cd "$src"
    patch -p1 --batch < "$TOOL_DIR/patches/iqtree3-mingw-clang.patch"
  )
  # IQ-TREE bundles ELF libomp.a/libompstatic.a for its non-Windows builds.
  # CMake adds -L<src>/lib on WIN32, so -lomp would pick the ELF archive and
  # ld.lld rejects it. Remove them; CLANG64 supplies the COFF libomp.a.
  rm -f "$src/lib/libomp.a" "$src/lib/libompstatic.a"
fi

cmake_args=(
  -S "$src"
  -B "$cmake_build"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
flags=()

case "$CYAN_PLATFORM" in
  windows)
    # Override the GCC default from common.sh. The Clang branch in IQ-TREE's
    # CMake does not add "novx" on Windows, so kernelavx/kernelfma are built.
    : "${MINGW_PREFIX:=/mingw64}"
    CC=clang
    CXX=clang++
    export CC CXX
    command -v "$CC" >/dev/null 2>&1 || die "clang not found in PATH"
    cmake_args+=(
      -DCMAKE_C_COMPILER="$CC"
      -DCMAKE_CXX_COMPILER="$CXX"
      -DCMAKE_PREFIX_PATH="$MINGW_PREFIX"
      -DBOOST_ROOT="$MINGW_PREFIX"
      -DBoost_INCLUDE_DIR="$MINGW_PREFIX/include"
      -DEIGEN3_INCLUDE_DIR="$MINGW_PREFIX/include/eigen3"
    )
    flags=(static cpp14)
    ;;
  linux)
    cmake_args+=(
      -DBoost_INCLUDE_DIR=/usr/include
      -DEIGEN3_INCLUDE_DIR=/usr/include/eigen3
    )
    flags=(static)
    ;;
  macos)
    command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS"
    boost_prefix="$(brew --prefix boost)"
    eigen_prefix="$(brew --prefix eigen)"
    libomp_prefix="$(brew --prefix libomp)"
    export CPPFLAGS="-I$libomp_prefix/include ${CPPFLAGS:-}"
    export CXXFLAGS="-I$libomp_prefix/include ${CXXFLAGS:-}"
    export LDFLAGS="-L$libomp_prefix/lib ${LDFLAGS:-}"
    cmake_args+=(
      -DBoost_INCLUDE_DIR="$boost_prefix/include"
      -DEIGEN3_INCLUDE_DIR="$eigen_prefix/include/eigen3"
    )
    # A fully static link is not supported on macOS. The default build links
    # Homebrew libomp; the dylib is copied into the package below.
    ;;
  *)
    die "unsupported platform: $CYAN_PLATFORM"
    ;;
esac

if [[ ${#flags[@]} -gt 0 ]]; then
  cmake_args+=(-DIQTREE_FLAGS="${flags[*]}")
fi

log "Configuring IQ-TREE $version ($CYAN_PLATFORM $CYAN_ARCH, ${CXX})"
cmake "${cmake_args[@]}"

log "Building IQ-TREE $version"
cmake --build "$cmake_build" --target iqtree3 --parallel "$CYAN_JOBS"

bin="$cmake_build/iqtree3$CYAN_EXE"
[[ -f "$bin" ]] || die "build did not produce $bin"

cp "$bin" "$stage/"
cp "$TOOL_DIR/VERSION" "$stage/"
cp "$src/LICENSE" "$stage/LICENSE"
cp "$src/README.md" "$stage/README.md"
cp "$src/cmaple/LICENSE" "$stage/LICENSE-CMAPLE"
cp "$src/lsd2/LICENSE" "$stage/LICENSE-LSD2"
cp "$src/example/example.phy" "$stage/"
cp "$src/example/example.nex" "$stage/"
cp "$src/example/models.nex" "$stage/"

# ----------------------------------------------------------------------
# Runtime libraries
# ----------------------------------------------------------------------
if [[ "$CYAN_PLATFORM" == windows ]]; then
  # IQ-TREE's CMake links this DLL explicitly for Clang/WIN32 builds.
  [[ -f "$src/lib/libiomp5md.dll" ]] \
    || die "missing vendored libiomp5md.dll"
  cp "$src/lib/libiomp5md.dll" "$stage/"
  # Copy any other MinGW runtime DLL the linker left dynamic, even though
  # "static" normally removes libgcc/libstdc++/libwinpthread.
  while IFS= read -r dll; do
    [[ -n "$dll" && -f "$dll" ]] || continue
    case "$dll" in
      "$MINGW_PREFIX"/*|"$src"/*) ;;
      *) continue ;;
    esac
    base="$(basename "$dll")"
    [[ -f "$stage/$base" ]] || cp "$dll" "$stage/$base"
  done < <(ldd "$stage/iqtree3.exe" 2>/dev/null | awk '/=>/ {print $3}' || true)
elif [[ "$CYAN_PLATFORM" == macos ]]; then
  # Keep non-system dylibs (libomp) beside the binary and point the loader at
  # the package directory. Homebrew paths are absolute and not portable.
  dylibs=()
  while IFS= read -r lib; do
    [[ -n "$lib" ]] || continue
    case "$lib" in
      /usr/lib/*|/System/*) continue ;;
      @*)
        base="$(basename "$lib")"
        lib_path="$libomp_prefix/lib/$base"
        ;;
      *)
        base="$(basename "$lib")"
        lib_path="$lib"
        ;;
    esac
    [[ -f "$lib_path" ]] || continue
    cp "$lib_path" "$stage/$base"
    install_name_tool -change "$lib" "@loader_path/$base" \
      "$stage/iqtree3" 2>/dev/null || true
    dylibs+=("$stage/$base")
  done < <(otool -L "$stage/iqtree3" | tail -n +2 | awk '{print $1}')
  for dylib in "${dylibs[@]}"; do
    codesign --force --sign - "$dylib" >/dev/null 2>&1 || true
  done
  codesign --force --sign - "$stage/iqtree3" >/dev/null 2>&1 || true
fi

if [[ "$CYAN_PLATFORM" == macos ]]; then
  "$STRIP" -x "$stage/iqtree3" 2>/dev/null || true
  codesign --force --sign - "$stage/iqtree3" >/dev/null 2>&1 || true
else
  "$STRIP" --strip-unneeded "$stage/iqtree3$CYAN_EXE" 2>/dev/null || true
fi

# ----------------------------------------------------------------------
# Verify the packaged binary can start and reports the expected version.
# ----------------------------------------------------------------------
version_out="$("$stage/iqtree3$CYAN_EXE" --version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"IQ-TREE version $version"* ]] \
  || die "unexpected version output: $version_out"

cat > "$stage/README-CYAN.txt" <<EOF
IQ-TREE $version built from the vendored upstream source.

Windows: Clang (MinGW) is used deliberately. IQ-TREE's CMake disables AVX
("novx") for GCC on Windows, which would cap the runtime at SSE4.2. Clang
keeps the AVX and FMA kernels; a typical AVX2 host prints:
    Host:    ... (AVX2, FMA3, ...)
    Kernel:  AVX+FMA - N threads (...)
Linux: GCC, statically linked. macOS: Apple Clang with Homebrew libomp
(bundled as libomp.dylib).

CMAPLE is disabled on Windows by upstream; it is included on Linux/macOS.
LSD2 dating is included on all platforms.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
