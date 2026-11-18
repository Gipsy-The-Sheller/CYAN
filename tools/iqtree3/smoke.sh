#!/usr/bin/env bash
#
# Smoke-test the packaged IQ-TREE 3 build.
#
# Runs a small maximum-likelihood analysis on the upstream example alignment
# and checks the reported version and the runtime instruction-set kernel.
# On x86_64 the kernel must contain AVX: a GCC Windows build would silently
# fall back to SSE because IQ-TREE's CMake adds "novx" for that toolchain.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=iqtree3
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/iqtree3$CYAN_EXE"
[[ -x "$bin" ]] || die "missing packaged IQ-TREE binary: $bin"

version_out="$("$bin" --version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"IQ-TREE version $version"* ]] \
  || die "unexpected version output: $version_out"

if [[ "$CYAN_PLATFORM" == macos && -f "$pkg/libomp.dylib" ]]; then
  otool -L "$bin" | grep -q '@loader_path/libomp.dylib' \
    || die "libomp.dylib is not referenced through @loader_path"
fi

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$pkg/example.phy" "$smoke/example.phy"

(
  cd "$smoke"
  "$bin" -s example.phy -m JC -nt 2 -seed 1 -redo -pre smoke \
    > run.log 2>&1
) || {
  tail -n 60 "$smoke/run.log" >&2 || true
  die "IQ-TREE example analysis failed"
}

tr -d '\r' < "$smoke/run.log" > "$smoke/run.clean.log"

grep -q 'Kernel:' "$smoke/run.clean.log" \
  || die "IQ-TREE did not report a likelihood kernel"
if [[ "$CYAN_ARCH" == x64 ]]; then
  grep -q 'Kernel:.*AVX' "$smoke/run.clean.log" \
    || die "IQ-TREE fell back to a non-AVX kernel (novx?)"
fi
grep -q 'BEST SCORE FOUND' "$smoke/run.clean.log" \
  || die "IQ-TREE did not report a best score"
[[ -s "$smoke/smoke.treefile" ]] \
  || die "IQ-TREE produced no treefile"

kernel="$(grep 'Kernel:' "$smoke/run.clean.log" | head -n 1)"
log "IQ-TREE smoke test passed ($kernel)"
