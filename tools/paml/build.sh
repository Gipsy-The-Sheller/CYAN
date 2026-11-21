#!/usr/bin/env bash
#
# Build PAML 4.10.10.
#
# PAML uses a plain Makefile and ANSI C. Windows and Linux builds are
# static. The dat/ directory is shipped because codeml/baseml read model
# tables such as dat/wag.dat at run time.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=paml
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

cflags="-O3 -Wall -Wno-unused-variable -Wno-unused-result"
ldflags=""
if [[ "$CYAN_PLATFORM" != macos ]]; then
  cflags="$cflags -static"
  ldflags="-static"
fi

log "Building PAML $version ($CYAN_PLATFORM $CYAN_ARCH)"
# The mcmctree recipe also builds infinitesites; there is no separate target.
make -C "$work" -j "$CYAN_JOBS" \
  CC="$CC" CFLAGS="$cflags" LDFLAGS="$ldflags" all

programs=(baseml basemlg codeml evolver mcmctree pamp yn00 chi2 ds infinitesites)
for name in "${programs[@]}"; do
  bin="$work/$name$CYAN_EXE"
  [[ -f "$bin" ]] || die "PAML binary not found: $bin"
  cp "$bin" "$stage/$name$CYAN_EXE"
  if [[ "$CYAN_PLATFORM" == macos ]]; then
    "$STRIP" -x "$stage/$name$CYAN_EXE" 2>/dev/null || true
  else
    "$STRIP" --strip-unneeded "$stage/$name$CYAN_EXE" 2>/dev/null || true
  fi
done

cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp -a "$TOOL_DIR/dat" "$stage/dat"
cp -a "$TOOL_DIR/examples" "$stage/examples"

cat > "$stage/README-CYAN.txt" <<EOF
PAML $version
=============

Built from abacus-gene/paml tag v4.10.10
($(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8)).

Programs: baseml, basemlg, codeml, evolver, mcmctree, pamp, yn00,
chi2, ds, infinitesites.

The package root is paml/, so extracting into YR_MPE/bin/ yields
YR_MPE/bin/paml/paml(.exe). Keep the bundled dat/ directory; codeml and
baseml read model tables from it (for example dat/wag.dat).

Example runs:
  cp examples/yn00.ctl .
  yn00 yn00.ctl
  # output: yn

PAML is distributed under GPL-3.0; see LICENSE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
