#!/usr/bin/env bash
#
# Stage the MAFFT 7.505 Windows x64 package.
#
# MAFFT's Windows distribution is a prebuilt native payload plus a small
# MSYS2 environment used by its shell launcher. CYAN repacks those upstream
# binaries; it does not build MAFFT from source. The runtime is reduced to the
# utilities and DLLs that `usr/bin/mafft` actually invokes (bash-min).
#
# The two archives under src/ are checksum-pinned. Keeping them as archives
# also preserves the CRLF line endings of mafft.bat and the executable bits
# of the native helpers.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=mafft
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
[[ "$CYAN_PLATFORM-$CYAN_ARCH" == windows-x64 ]] \
  || die "MAFFT is packaged only for windows-x64 (got $CYAN_PLATFORM-$CYAN_ARCH)"

build="$CYAN_BUILD/$tool"
stage="$CYAN_BUILD/stage/$tool"
payload="$TOOL_DIR/src/mafft-$version-win64-payload.tar.xz"
runtime="$TOOL_DIR/src/mafft-$version-bash-min-runtime.tar.xz"

[[ -f "$payload" ]] || die "missing payload archive: $payload"
[[ -f "$runtime" ]] || die "missing runtime archive: $runtime"

log "Verifying vendored MAFFT archives"
while read -r expected name; do
  expected="${expected%$'\r'}"
  name="${name%$'\r'}"
  [[ -n "$expected" ]] || continue
  name="${name#\*}"
  actual="$(sha256_file "$TOOL_DIR/src/$name")"
  [[ "$actual" == "$expected" ]] \
    || die "checksum mismatch for $name (expected $expected, got $actual)"
done < "$TOOL_DIR/src/SHA256SUMS"

rm -rf "$build"
mkdir -p "$stage"

extract() {
  local archive="$1" dest="$2"
  if ! tar -xJf "$archive" -C "$dest"; then
    log_err "tar could not read $archive; retrying through xz"
    xz -dc "$archive" | tar -xf - -C "$dest"
  fi
}

log "Unpacking MAFFT $version payload and bash-min runtime"
extract "$payload" "$stage"
extract "$runtime" "$stage"

required=(
  mafft.bat
  usr/bin/bash.exe
  usr/bin/mafft
  usr/bin/awk.exe
  usr/bin/sed.exe
  usr/bin/grep.exe
  usr/bin/msys-2.0.dll
  usr/lib/mafft/tbfast.exe
  usr/lib/mafft/version.exe
)
for path in "${required[@]}"; do
  [[ -f "$stage/$path" ]] || die "MAFFT package is missing $path"
done

# Guard against accidentally restoring the full 20 MB runtime: the whole
# point of this package is the validated bash-min whitelist.
runtime_files="$(
  find "$stage/usr/bin" -maxdepth 1 -type f -printf '%f\n' | sort
)"
expected_runtime_files="$(
  printf '%s\n' \
    awk.exe basename.exe bash.exe cat.exe cp.exe dirname.exe env.exe \
    expr.exe grep.exe head.exe mafft mkdir.exe mktemp.exe \
    msys-2.0.dll msys-gmp-10.dll msys-iconv-2.dll msys-intl-8.dll \
    msys-mpfr-4.dll msys-pcre-1.dll msys-readline6.dll \
    mv.exe rm.exe sed.exe tail.exe tr.exe uname.exe wc.exe | sort
)"
[[ "$runtime_files" == "$expected_runtime_files" ]] \
  || die "unexpected usr/bin runtime file set"

cp "$TOOL_DIR/LICENSE-MAFFT" "$TOOL_DIR/LICENSE-MSYS2.txt" \
   "$TOOL_DIR/COPYING-GPL-3" "$TOOL_DIR/VERSION" "$TOOL_DIR/README.md" "$stage/"
cp "$TOOL_DIR/examples/example.fa" "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
MAFFT $version for Windows x64, bash-min runtime
=================================================

This package is a repackaging of the official MAFFT $version Windows x64
binary distribution. It is not rebuilt by CYAN.

Entry point:
  mafft.bat

YR-MPE resolves /bin/mafft/mafft.bat, so extract this archive into
YR_MPE/bin/ to obtain YR_MPE/bin/mafft/mafft.bat.

Layout:
  mafft.bat              official Windows launcher
  usr/bin/mafft          official MAFFT shell driver (unmodified)
  usr/bin/*.exe, *.dll   minimal bash/awk/sed/grep/coreutils runtime
  usr/lib/mafft/*.exe    native MAFFT alignment engines

The runtime is limited to the utilities and DLLs exercised by the YR-MPE
plugin: bash, awk, sed, grep, coreutils helpers, and their MSYS2 DLLs.
The alignment engines and the mafft shell driver are unchanged upstream
7.505 binaries/scripts.

Typical usage:
  mafft.bat --auto input.fa
  mafft.bat --maxiterate 1000 --localpair input.fa
  mafft.bat --auto --adjustdirection input.fa

See LICENSE-MAFFT (BSD-3-Clause) and LICENSE-MSYS2.txt (bundled runtime).
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
