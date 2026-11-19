#!/usr/bin/env bash
#
# Stage the IcyTree static web application.
#
# IcyTree is pure client-side JavaScript. CYAN does not compile it; the
# checked-in src/ tree is the upstream site at commit 48ed43e, including the
# vendored jQuery/jQuery UI/PapaParse/Plotly/FileSaver libraries. The package
# is platform-neutral despite the windows-x64 label: it is only built once so
# the matrix does not publish five identical copies.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=icytree
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
[[ "$CYAN_PLATFORM-$CYAN_ARCH" == windows-x64 ]] \
  || die "IcyTree is a platform-neutral package; build it once on windows-x64"

build="$CYAN_BUILD/$tool"
stage="$CYAN_BUILD/stage/$tool"

rm -rf "$build"
mkdir -p "$stage"
cp -a "$TOOL_DIR/src"/. "$stage"/
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/primates.newick" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
IcyTree (static HTML)
=====================

Upstream: https://github.com/tgvaughan/icytree
Commit:   48ed43e (2025-05-19)
License:  GPL-3.0 (see LICENSE)

This package is the complete client-side IcyTree site. Open index.html in a
modern browser; no server or network access is required. The applications
HTML, CSS and JavaScript are unchanged from upstream.

For YR-MPE, copy this directory to YR_MPE/src/icytree (the location expected
by YR_MPE/icytree.py). The package is platform-neutral and may also be used
on Linux and macOS.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
