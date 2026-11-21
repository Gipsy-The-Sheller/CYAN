#!/usr/bin/env bash
#
# Build BMGE 2.0 as a Java 11-compatible jar.
#
# BMGE v2 is a single-file Java program. The jar is platform-neutral; CYAN
# builds it once in the windows-x64 job. A Java 11+ runtime is required at
# run time (YR-MPE's MACSE bundle also ships one).

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=bmge
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
[[ "$CYAN_PLATFORM-$CYAN_ARCH" == windows-x64 ]] \
  || die "BMGE is a platform-neutral jar; build it once on windows-x64"
command -v javac >/dev/null 2>&1 || die "javac (JDK 11+) is required"

build="$CYAN_BUILD/$tool"
stage="$CYAN_BUILD/stage/$tool"
rm -rf "$build" "$stage"
mkdir -p "$build/classes" "$stage"
cp "$TOOL_DIR/src/BMGE.java" "$build/"
cp -a "$TOOL_DIR/src/bmge" "$build/bmge"

log "Compiling BMGE $version ($(javac -version 2>&1))"
(
  cd "$build"
  javac --release 11 -d classes BMGE.java bmge/*.java
  if command -v jar >/dev/null 2>&1; then
    jar cfe BMGE.jar BMGE -C classes .
  else
    # Some Oracle javapath shims expose javac but not jar; a jar is a zip.
    command -v zip >/dev/null 2>&1 || die "neither jar nor zip is available"
    mkdir -p classes/META-INF
    printf 'Manifest-Version: 1.0\r\nMain-Class: BMGE\r\n\r\n' \
      > classes/META-INF/MANIFEST.MF
    (
      cd classes
      zip -qr ../BMGE.jar META-INF
      zip -qr ../BMGE.jar . -i '*.class'
    )
  fi
)

cp "$build/BMGE.jar" "$stage/BMGE.jar"
cp "$TOOL_DIR/LICENSE" "$TOOL_DIR/README.md" "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples/example.fna" "$stage/"

printf '@echo off\r\njava -jar "%%~dp0BMGE.jar" %%*\r\n' > "$stage/BMGE.bat"
cat > "$stage/bmge" <<'EOF'
#!/bin/sh
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec java -jar "$dir/BMGE.jar" "$@"
EOF
chmod +x "$stage/bmge"

cat > "$stage/README-CYAN.txt" <<EOF
BMGE $version
=============

Compiled from GIPhy/BMGE commit
$(grep '^commit=' "$TOOL_DIR/UPSTREAM" | cut -d= -f2 | cut -c1-8)
with --release 11, so any Java 11+ runtime can execute it.

Entry points:
  BMGE.bat        Windows launcher
  bmge            Unix launcher
  BMGE.jar        platform-neutral jar

Example:
  BMGE.bat -i example.fna -t NT -o selected.fna
  ./bmge -i example.fna -t NT -o selected.fna

The package root is BMGE/, matching the existing YR-MPE config path
YR_MPE/bin/BMGE/. A Java 11+ runtime is required; the package does not
bundle a JRE.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
