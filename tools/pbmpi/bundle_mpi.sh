#!/usr/bin/env bash
#
# Bundle the OpenMPI runtime used to build PhyloBayes-MPI into the package.
# This is used on Linux and macOS only; Windows uses the MS-MPI files copied
# by build.sh.
#
# Layout produced under <stage>/:
#   mpi/bin/{mpiexec,mpirun,orterun,prterun,...}
#   mpi/lib/{libmpi*,libopen-*,libprrte*,libpmix*,...}
#   mpi/lib/openmpi/  mpi/lib/prte/  mpi/share/openmpi/  mpi/share/prte/
#   mpi/libexec/{orted,prted,...}
#   mpiexec, mpirun, pb_mpi, ... (shell wrappers that set OPAL_PREFIX)

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

stage="${1:?usage: bundle_mpi.sh <stage-dir>}"
[[ "$CYAN_PLATFORM" == linux || "$CYAN_PLATFORM" == macos ]] || exit 0

mpi_dir="$stage/mpi"
rm -rf "$mpi_dir"
mkdir -p "$mpi_dir/lib"

ompi_path() {
  ompi_info --path "$1" 2>/dev/null | sed -n 's/^[^:]*: //p' | head -n 1 || true
}
prte_path() {
  prte_info --path "$1" 2>/dev/null | sed -n 's/^[^:]*: //p' | head -n 1 || true
}

mpi_prefix="$(ompi_path prefix)"
mpi_bindir="$(ompi_path bindir)"
mpi_libdir="$(ompi_path libdir)"
mpi_libexecdir="$(ompi_path libexecdir)"
mpi_pkglibdir="$(ompi_path pkglibdir)"
mpi_pkgdatadir="$(ompi_path pkgdatadir)"

prte_prefix="$(prte_path prefix)"
prte_bindir="$(prte_path bindir)"
prte_libdir="$(prte_path libdir)"
prte_libexecdir="$(prte_path libexecdir)"

if [[ -z "$mpi_bindir" ]]; then
  mpiexec_abs="$(command -v mpiexec || true)"
  [[ -n "$mpiexec_abs" ]] || die "mpiexec not found; cannot bundle the MPI runtime"
  mpi_bindir="$(dirname "$(readlink -f "$mpiexec_abs" 2>/dev/null || echo "$mpiexec_abs")")"
fi

# OPAL_PREFIX relocation preserves the directory layout relative to the
# original install prefix. Debian puts libs and MCA components under
# lib/<multiarch>/..., while Homebrew uses a flat lib/. Compute the relative
# locations instead of assuming a layout.
rel_path() {
  local base="$1" path="$2"
  if [[ -n "$base" && "$path" == "$base"/* ]]; then
    printf '%s\n' "${path#"$base"/}"
  else
    printf '%s\n' "$(basename "$path")"
  fi
}

mpi_bin_rel="$(rel_path "$mpi_prefix" "$mpi_bindir")"
mpi_pkglib_rel="$(rel_path "$mpi_prefix" "$mpi_pkglibdir")"
mpi_pkgdata_rel="$(rel_path "$mpi_prefix" "$mpi_pkgdatadir")"
mpi_libexec_rel="$(rel_path "$mpi_prefix" "$mpi_libexecdir")"
prte_lib_rel="$(rel_path "$prte_prefix" "$prte_prefix/lib/prte")"
prte_share_rel="$(rel_path "$prte_prefix" "$prte_prefix/share/prte")"
prte_libexec_rel="$(rel_path "$prte_prefix" "$prte_libexecdir")"
[[ -n "$mpi_bin_rel" ]] || mpi_bin_rel=bin
[[ -n "$mpi_pkglib_rel" ]] || mpi_pkglib_rel=lib/openmpi
[[ -n "$mpi_pkgdata_rel" ]] || mpi_pkgdata_rel=share/openmpi
[[ -n "$mpi_libexec_rel" ]] || mpi_libexec_rel=libexec
mkdir -p "$mpi_dir/$mpi_bin_rel"

copy_exe() {
  local name="$1" src="$2"
  [[ -f "$src" ]] || return 0
  cp -L "$src" "$mpi_dir/$mpi_bin_rel/$name"
  chmod +x "$mpi_dir/$mpi_bin_rel/$name"
}

for name in mpiexec mpirun orterun prterun prte; do
  src="$(command -v "$name" 2>/dev/null || true)"
  [[ -n "$src" ]] && copy_exe "$name" "$src"
done
for dir in "$mpi_bindir" "$mpi_libexecdir" "$mpi_pkglibdir" \
           "$prte_bindir" "$prte_libexecdir"; do
  [[ -n "$dir" && -d "$dir" ]] || continue
  for name in orted prted prte prterun ompi_info prte_info; do
    [[ -f "$dir/$name" ]] && copy_exe "$name" "$dir/$name"
  done
done

if [[ ! -f "$mpi_dir/$mpi_bin_rel/mpiexec" ]]; then
  for candidate in orterun prterun; do
    if [[ -f "$mpi_dir/$mpi_bin_rel/$candidate" ]]; then
      cp "$mpi_dir/$mpi_bin_rel/$candidate" "$mpi_dir/$mpi_bin_rel/mpiexec"
      break
    fi
  done
fi
[[ -f "$mpi_dir/$mpi_bin_rel/mpiexec" ]] || die "could not bundle mpiexec"
if [[ ! -f "$mpi_dir/$mpi_bin_rel/mpirun" ]]; then
  cp "$mpi_dir/$mpi_bin_rel/mpiexec" "$mpi_dir/$mpi_bin_rel/mpirun"
fi

copy_lib() {
  local src="$1"
  [[ -f "$src" ]] || return 0
  local base
  base="$(basename "$src")"
  [[ -f "$mpi_dir/lib/$base" ]] && return 0
  cp -L "$src" "$mpi_dir/lib/$base"
}

for dir in "$mpi_libdir" "$prte_libdir"; do
  [[ -n "$dir" && -d "$dir" ]] || continue
  for pattern in 'libmpi.*' 'libopen-*.*' 'libprrte*.*' 'libpmix*.*' \
                 'libhwloc*.*' 'libevent*.*' 'libfabric*.*' 'libpsm2*.*' \
                 'libnl*.*' 'libudev*.*' 'libnuma*.*' 'libz.*' 'liblzma*.*' \
                 'libffi*.*' 'libxml2*.*' 'libmunge*.*'; do
    for file in "$dir"/$pattern; do
      copy_lib "$file"
    done
  done
done

copy_tree() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$dest"
  cp -aL "$src/." "$dest/"
}

copy_tree "$mpi_pkglibdir" "$mpi_dir/$mpi_pkglib_rel"
copy_tree "$mpi_pkgdatadir" "$mpi_dir/$mpi_pkgdata_rel"
copy_tree "$prte_prefix/lib/prte" "$mpi_dir/$prte_lib_rel"
copy_tree "$prte_prefix/share/prte" "$mpi_dir/$prte_share_rel"
copy_tree "$prte_libexecdir" "$mpi_dir/$prte_libexec_rel"

for name in orted prted; do
  if [[ -f "$mpi_dir/$mpi_bin_rel/$name" ]]; then
    mkdir -p "$mpi_dir/$mpi_libexec_rel"
    cp "$mpi_dir/$mpi_bin_rel/$name" "$mpi_dir/$mpi_libexec_rel/$name"
  fi
done

if [[ "$CYAN_PLATFORM" == linux ]]; then
  {
    find "$mpi_dir" -type f -print0 | while IFS= read -r -d '' file; do
      ldd "$file" 2>/dev/null || true
    done
    # The application binaries also name libmpi/libmpi_cxx and their
    # transitive dependencies.
    for file in "$stage"/*.bin; do
      [[ -f "$file" ]] || continue
      ldd "$file" 2>/dev/null || true
    done
  } | awk '/=> \// {print $3} /^\t\/.*/{print $1}' | sort -u |
  while IFS= read -r lib; do
    [[ -f "$lib" ]] || continue
    base="$(basename "$lib")"
    case "$base" in
      libc.so*|libm.so*|libmvec*|libdl.so*|libpthread.so*|librt.so*|ld-linux*|libresolv*|libnss*|libutil*) continue ;;
    esac
    copy_lib "$lib"
  done
else
  # macOS: collect Homebrew/OpenMPI dependencies, then rewrite absolute
  # install names to @rpath so the package can be moved anywhere. Repeat
  # the dependency pass so transitive dependencies are copied too.
  for _pass in 1 2 3; do
    {
      find "$mpi_dir" -type f -print0 | while IFS= read -r -d '' file; do
        file -b "$file" | grep -q 'Mach-O' || continue
        otool -L "$file" 2>/dev/null | tail -n +2 | awk '{print $1}'
      done
      for file in "$stage"/*.bin; do
        [[ -f "$file" ]] || continue
        file -b "$file" | grep -q 'Mach-O' || continue
        otool -L "$file" 2>/dev/null | tail -n +2 | awk '{print $1}'
      done
    } | while IFS= read -r dep; do
      case "$dep" in
        /opt/homebrew/*|/usr/local/*|"$mpi_prefix"*) copy_lib "$dep" ;;
      esac
    done
  done

  rewrite_macho() {
    local file="$1"
    file -b "$file" | grep -q 'Mach-O' || return 0
    if otool -D "$file" 2>/dev/null | tail -n +2 | grep -q .; then
      install_name_tool -id "@rpath/$(basename "$file")" "$file" 2>/dev/null || true
    fi
    otool -L "$file" 2>/dev/null | tail -n +2 | awk '{print $1}' |
    while IFS= read -r dep; do
      case "$dep" in
        /opt/homebrew/*|/usr/local/*|"$mpi_prefix"*)
          install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$file" 2>/dev/null || true
          ;;
      esac
    done
    for rpath in "@loader_path" "@loader_path/.." "@loader_path/../lib" "@loader_path/mpi/lib"; do
      install_name_tool -add_rpath "$rpath" "$file" 2>/dev/null || true
    done
    codesign --force --sign - "$file" >/dev/null 2>&1 || true
  }

  find "$mpi_dir" -type f -print0 | while IFS= read -r -d '' file; do
    rewrite_macho "$file"
  done
  for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
    rewrite_macho "$stage/$prog.bin"
  done
fi

write_wrapper() {
  local path="$1" target="$2"
  {
    printf '#!/bin/sh\n'
    printf 'PKG="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"\n'
    printf 'export OPAL_PREFIX="$PKG/mpi"\n'
    printf 'export PRTE_PREFIX="$PKG/mpi"\n'
    printf 'export PATH="$PKG/mpi/%s:$PATH"\n' "$mpi_bin_rel"
    printf 'export LD_LIBRARY_PATH="$PKG/mpi/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
    printf 'export DYLD_LIBRARY_PATH="$PKG/mpi/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"\n'
    printf 'exec "$PKG/%s" "$@"\n' "$target"
  } > "$path"
  chmod +x "$path"
}

write_wrapper "$stage/mpiexec" "mpi/$mpi_bin_rel/mpiexec"
write_wrapper "$stage/mpirun" "mpi/$mpi_bin_rel/mpirun"
for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  write_wrapper "$stage/$prog" "$prog.bin"
done

log "Bundled MPI runtime: $(du -sh "$mpi_dir" | awk '{print $1}')"
