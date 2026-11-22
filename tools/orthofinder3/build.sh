#!/usr/bin/env bash
#
# Build OrthoFinder 3.0.1b1 as a PyInstaller one-folder application.
#
# OrthoFinder is Python, so "packaging the venv" here means freezing the
# interpreter and its dependencies into _internal/ with PyInstaller. The
# native search, clustering, alignment and tree tools are CYAN packages and
# are copied into orthofinder/bin/, where OrthoFinder prepends them to PATH.
#
# Windows and Linux x64 are supported. MAFFT is CYAN's Windows package on
# Windows and the Linux x64 runtime shipped by OrthoFinder upstream on Linux;
# macOS and Linux arm64 are left for a later stage.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=orthofinder3
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
build="$CYAN_BUILD/$tool"
work="$build/src"
stage="$CYAN_BUILD/stage/$tool"
venv="$build/venv"

python_bin="${PYTHON:-python}"
command -v "$python_bin" >/dev/null 2>&1 || die "Python 3.11+ is required (set PYTHON)"
"$python_bin" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' \
  || die "Python 3.11+ is required (found: $("$python_bin" --version 2>&1))"

ensure_tool() {
  local name="$1" marker="$2" required="${3:-optional}"
  if [[ -f "$marker" ]]; then
    return 0
  fi
  if ! cyan_tool_supported "$CYAN_ROOT/tools/$name"; then
    if [[ "$required" == required ]]; then
      die "$name is required by $tool but does not support $CYAN_PLATFORM_LABEL $CYAN_ARCH"
    fi
    log "Skipping optional tool $name (unsupported on this target)"
    return 0
  fi
  log "Building dependency $name for $tool"
  (
    cd "$CYAN_ROOT/tools/$name"
    bash ./build.sh
  )
}

ensure_tool diamond "$CYAN_BUILD/stage/diamond/diamond$CYAN_EXE" required
ensure_tool mcl "$CYAN_BUILD/stage/mcl/mcl$CYAN_EXE" required
ensure_tool fasttree "$CYAN_BUILD/stage/fasttree/FastTree$CYAN_EXE"
ensure_tool fastme "$CYAN_BUILD/stage/fastme/fastme$CYAN_EXE"
ensure_tool aster "$CYAN_BUILD/stage/aster/astral-pro$CYAN_EXE"
ensure_tool famsa "$CYAN_BUILD/stage/famsa/famsa$CYAN_EXE"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  ensure_tool mafft "$CYAN_BUILD/stage/mafft/mafft.bat"
fi

rm -rf "$build" "$stage"
mkdir -p "$work" "$stage"
cp -a "$TOOL_DIR/src"/. "$work"/

log "Applying OrthoFinder portability patch"
(
  cd "$work"
  patch -p1 --batch --forward < "$TOOL_DIR/patches/orthofinder3-windows.patch"
)

log "Creating Python build environment"
"$python_bin" -m venv "$venv"
if [[ "$CYAN_PLATFORM" == windows ]]; then
  py="$venv/Scripts/python.exe"
  pyi="$venv/Scripts/pyinstaller.exe"
else
  py="$venv/bin/python"
  pyi="$venv/bin/pyinstaller"
fi
"$py" -m pip install --disable-pip-version-check --quiet --upgrade pip setuptools wheel
"$py" -m pip install --disable-pip-version-check --quiet -r "$work/requirements.txt" pyinstaller

log "Freezing OrthoFinder $version with PyInstaller"
(
  cd "$work"
  "$pyi" --noconfirm --clean --onedir --name orthofinder \
    --distpath "$work/dist" --workpath "$work/pyi-build" --specpath "$work" \
    orthofinder.py
)

app="$work/dist/orthofinder"
[[ -x "$app/orthofinder$CYAN_EXE" ]] || die "PyInstaller output missing: $app"
cp "$work/scripts_of/config.json" "$app/config.json"

bindir="$app/bin"
mkdir -p "$bindir"

copy_tool() {
  local src="$1"
  [[ -f "$src" ]] || die "missing native tool: $src"
  cp "$src" "$bindir/"
}

copy_tool "$CYAN_BUILD/stage/diamond/diamond$CYAN_EXE"
copy_tool "$CYAN_BUILD/stage/mcl/mcl$CYAN_EXE"
copy_tool "$CYAN_BUILD/stage/fasttree/FastTree$CYAN_EXE"
copy_tool "$CYAN_BUILD/stage/fastme/fastme$CYAN_EXE"
copy_tool "$CYAN_BUILD/stage/aster/astral-pro$CYAN_EXE"
if [[ -f "$CYAN_BUILD/stage/famsa/famsa$CYAN_EXE" ]]; then
  copy_tool "$CYAN_BUILD/stage/famsa/famsa$CYAN_EXE"
  if [[ "$CYAN_PLATFORM" == windows ]]; then
    for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
      cp "$CYAN_BUILD/stage/famsa/$dll" "$bindir/"
    done
  fi
fi

if [[ "$CYAN_PLATFORM" == windows ]]; then
  [[ -f "$CYAN_BUILD/stage/mafft/mafft.bat" ]] || die "missing MAFFT stage"
  cp "$CYAN_BUILD/stage/mafft/mafft.bat" "$bindir/"
  cp -a "$CYAN_BUILD/stage/mafft/usr" "$bindir/"
  mkdir -p "$bindir/usr/tmp"
elif [[ "$CYAN_PLATFORM" == linux && "$CYAN_ARCH" == x64 ]]; then
  log "Bundling OrthoFinder's Linux MAFFT runtime"
  tar -xzf "$TOOL_DIR/vendor/mafft-linux-x64.tar.gz" -C "$bindir"
  chmod +x "$bindir/mafft/bin/mafft" "$bindir/mafft/libexec/"*
  cp "$TOOL_DIR/vendor/LICENSE-MAFFT" "$stage/LICENSE-MAFFT"
fi

cp "$TOOL_DIR/src/License.md" "$stage/LICENSE"
cp "$TOOL_DIR/README.md" "$stage/README.md"
cp "$TOOL_DIR/src/README.md" "$stage/README-UPSTREAM.md"
cp "$TOOL_DIR/VERSION" "$stage/"
cp "$TOOL_DIR/examples"/*.fa "$stage/"
cp -a "$app"/. "$stage/"

cat > "$stage/README-CYAN.txt" <<EOF
OrthoFinder $version
====================

PyInstaller one-folder build. The Python runtime and numpy/scipy/scikit-learn/
biopython live in _internal/; the executable is orthofinder$CYAN_EXE.

Bundled native tools in bin/:
  diamond, mcl, FastTree, fastme, astral-pro, famsa
  MAFFT (mafft.bat + usr/ on Windows; mafft/ on Linux x64)

OrthoFinder prepends this bin/ directory to PATH. config.json is at the
package root because OrthoFinder reads it relative to the executable.

Examples:
  orthofinder$CYAN_EXE -f proteomes/ -t 8
  orthofinder$CYAN_EXE -f proteomes/ -t 8 -og -S diamond
  orthofinder$CYAN_EXE -f proteomes/ -t 8 -M msa -A famsa -T fasttree

The package root is orthofinder/, matching YR-MPE's configured
bin/orthofinder/orthofinder.exe path.
EOF

bash "$CYAN_ROOT/scripts/package_tool.sh" "$tool" "$stage"
