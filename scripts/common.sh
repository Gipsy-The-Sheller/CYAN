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

log_err() {
  printf '==> %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# True when tools/<name>/SUPPORTED_PLATFORMS lists the current target and,
# on Windows, REQUIRES_MSYSTEM (if present) contains the active MSYS2
# environment. A missing file means no restriction.
cyan_tool_supported() {
  local dir="$1"
  local target="${CYAN_PLATFORM}-${CYAN_ARCH}"
  if [[ -f "$dir/SUPPORTED_PLATFORMS" ]]; then
    tr -d '\r' < "$dir/SUPPORTED_PLATFORMS" | grep -qx "$target" || return 1
  fi
  if [[ "$CYAN_PLATFORM" == windows && -f "$dir/REQUIRES_MSYSTEM" ]]; then
    tr -d '\r' < "$dir/REQUIRES_MSYSTEM" | grep -qx "${MSYSTEM:-}" || return 1
  fi
  return 0
}

# Print the build.sh or smoke.sh paths selected by CYAN_TOOLS.
# CYAN_TOOLS accepts comma- or space-separated tool names; empty selects all.
# Tools that do not support the current target are skipped.
cyan_tool_scripts() {
  local kind="${1:?usage: cyan_tool_scripts <build|smoke>}"
  local filter="${CYAN_TOOLS:-}"
  local target="${CYAN_PLATFORM}-${CYAN_ARCH}"
  filter="${filter//,/ }"
  local -a found=()

  if [[ -n "${filter// /}" ]]; then
    local name tool_dir
    for name in $filter; do
      tool_dir="$CYAN_ROOT/tools/$name"
      [[ -f "$tool_dir/$kind.sh" ]] \
        || die "unknown tool or missing $kind.sh: $name"
      if cyan_tool_supported "$tool_dir"; then
        found+=("$tool_dir/$kind.sh")
      else
        log_err "Skipping $name: not supported on $target"
      fi
    done
  else
    shopt -s nullglob
    local tool_dir
    for tool_dir in "$CYAN_ROOT"/tools/*; do
      [[ -f "$tool_dir/$kind.sh" ]] || continue
      if cyan_tool_supported "$tool_dir"; then
        found+=("$tool_dir/$kind.sh")
      else
        log_err "Skipping $(basename "$tool_dir"): not supported on $target"
      fi
    done
    shopt -u nullglob
  fi

  if [[ ${#found[@]} -gt 0 ]]; then
    printf '%s\n' "${found[@]}"
  fi
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

# Convert a Windows path to an MSYS path when cygpath is available.
cyan_windows_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

cyan_msmpi_inc() {
  local raw="${MSMPI_INC:-C:/Program Files (x86)/Microsoft SDKs/MPI/Include}"
  local path
  path="$(cyan_windows_path "$raw")"
  printf '%s\n' "${path%/}"
}

cyan_msmpi_lib() {
  local inc raw path
  inc="$(cyan_msmpi_inc)"
  raw="${MSMPI_LIB:-$(dirname "$inc")/Lib/x64}"
  path="$(cyan_windows_path "$raw")"
  printf '%s\n' "${path%/}"
}

# Locate mpiexec from the MS-MPI runtime.
cyan_mpiexec() {
  local -a candidates=()
  local raw="${MSMPI_BIN:-}"
  if [[ -n "$raw" ]]; then
    raw="${raw%/}"
    raw="${raw%\\}"
    candidates+=("$raw/mpiexec.exe")
  fi
  candidates+=(
    "C:/Program Files/Microsoft MPI/Bin/mpiexec.exe"
    "D:/Program Files/Microsoft MPI/Bin/mpiexec.exe"
  )

  local candidate path
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    path="$(cyan_windows_path "$candidate")"
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  command -v mpiexec.exe 2>/dev/null || command -v mpiexec 2>/dev/null || true
}

cyan_msmpi_license() {
  local candidate path
  for candidate in \
    "C:/Program Files/Microsoft MPI/License/MicrosoftMPI-Redistributable-EULA.rtf" \
    "D:/Program Files/Microsoft MPI/License/MicrosoftMPI-Redistributable-EULA.rtf"; do
    path="$(cyan_windows_path "$candidate")"
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 0
}
