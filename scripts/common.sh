#!/usr/bin/env bash
#
# Shared configuration for CYAN tool builds.
#
# Supported hosts:
#   Windows x64    MSYS2 MINGW64  (GCC)
#   Windows arm64  MSYS2 CLANGARM64 (Clang/LLD)
#   Linux x64/arm64
#   macOS arm64
#
# Source this file from every tool build script.

set -euo pipefail

if [[ -n "${CYAN_COMMON_LOADED:-}" ]]; then
  return 0
fi
CYAN_COMMON_LOADED=1

CYAN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CYAN_ROOT

CYAN_BUILD="${CYAN_BUILD:-$CYAN_ROOT/build}"
CYAN_DIST="${CYAN_DIST:-$CYAN_ROOT/dist}"
export CYAN_BUILD CYAN_DIST
mkdir -p "$CYAN_BUILD" "$CYAN_DIST"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) CYAN_PLATFORM=windows ;;
  Linux*)               CYAN_PLATFORM=linux ;;
  Darwin*)              CYAN_PLATFORM=macos ;;
  *)
    echo "Unsupported host OS: $(uname -s)" >&2
    exit 2
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  CYAN_HOST_ARCH=x64 ;;
  aarch64|arm64) CYAN_HOST_ARCH=arm64 ;;
  *)
    echo "Unsupported host architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

# The CI matrix sets CYAN_ARCH explicitly so an MSYS2 shell cannot select the
# wrong target by accident.
CYAN_ARCH="${CYAN_ARCH:-$CYAN_HOST_ARCH}"
case "$CYAN_ARCH" in
  x86_64|amd64|x64) CYAN_ARCH=x64 ;;
  arm64|aarch64)    CYAN_ARCH=arm64 ;;
  *)
    echo "Unsupported CYAN_ARCH: $CYAN_ARCH (use x64 or arm64)" >&2
    exit 2
    ;;
esac

case "$CYAN_PLATFORM" in
  windows) CYAN_PLATFORM_LABEL=Windows ;;
  linux)   CYAN_PLATFORM_LABEL=Linux ;;
  macos)   CYAN_PLATFORM_LABEL=macOS ;;
esac

CYAN_EXE=""
[[ "$CYAN_PLATFORM" == windows ]] && CYAN_EXE=".exe"

export CYAN_PLATFORM CYAN_PLATFORM_LABEL CYAN_ARCH CYAN_EXE

# Release label: tag name for tagged builds, otherwise dev-<sha8>.
CYAN_GIT_SHA="${GITHUB_SHA:-}"
if [[ -z "$CYAN_GIT_SHA" ]]; then
  CYAN_GIT_SHA="$(git -C "$CYAN_ROOT" rev-parse HEAD 2>/dev/null || true)"
fi
CYAN_GIT_SHA="$(printf '%s' "$CYAN_GIT_SHA" | tr -d '[:space:]')"
[[ -n "$CYAN_GIT_SHA" ]] || CYAN_GIT_SHA=unknown
CYAN_SHORT_SHA="${CYAN_GIT_SHA:0:8}"
if [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
  CYAN_RELEASE="${GITHUB_REF_NAME:-${GITHUB_REF#refs/tags/}}"
else
  CYAN_RELEASE="dev-${CYAN_SHORT_SHA}"
fi
CYAN_RELEASE="${CYAN_RELEASE//\//_}"
CYAN_RELEASE="$(printf '%s' "$CYAN_RELEASE" | tr -d '[:space:]')"
export CYAN_GIT_SHA CYAN_SHORT_SHA CYAN_RELEASE

# Toolchain selection.
if [[ "$CYAN_PLATFORM" == windows ]]; then
  if [[ "${MSYSTEM:-}" == "CLANGARM64" ]]; then
    CC="${CC:-clang}"
    CXX="${CXX:-clang++}"
    AR="${AR:-llvm-ar}"
    RANLIB="${RANLIB:-llvm-ranlib}"
    STRIP="${STRIP:-llvm-strip}"
  else
    CC="${CC:-gcc}"
    CXX="${CXX:-g++}"
    AR="${AR:-ar}"
    RANLIB="${RANLIB:-ranlib}"
    STRIP="${STRIP:-strip}"
  fi
else
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    CC="${CC:-clang}"
    CXX="${CXX:-clang++}"
  else
    CC="${CC:-gcc}"
    CXX="${CXX:-g++}"
  fi
  AR="${AR:-ar}"
  RANLIB="${RANLIB:-ranlib}"
  STRIP="${STRIP:-strip}"
fi
export CC CXX AR RANLIB STRIP

if [[ -z "${CYAN_JOBS:-}" ]]; then
  CYAN_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null \
    || nproc 2>/dev/null \
    || sysctl -n hw.ncpu 2>/dev/null \
    || echo 4)"
fi
export CYAN_JOBS

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  fi
}
