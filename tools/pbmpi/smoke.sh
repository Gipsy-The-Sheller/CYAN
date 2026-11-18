#!/usr/bin/env bash
#
# Smoke-test the staged PhyloBayes-MPI package: all five programs exist,
# pb_mpi reports 1.9, and the bundled launcher starts a two-rank MPI job.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=pbmpi
pkg="$CYAN_BUILD/stage/$tool"
pb="$pkg/pb_mpi$CYAN_EXE"
mpiexec="$pkg/mpiexec$CYAN_EXE"

for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  [[ -x "$pkg/$prog$CYAN_EXE" ]] \
    || die "missing packaged executable: $pkg/$prog$CYAN_EXE (run build.sh first)"
done
[[ -x "$mpiexec" ]] || die "missing packaged mpiexec: $mpiexec"

# OpenMPI refuses to start more ranks than slots on small runners; this
# variable is harmless for MPICH and MS-MPI.
export OMPI_MCA_rmaps_base_oversubscribe=1

mpi_root_args=()
if [[ "$CYAN_PLATFORM" != windows ]] \
   && [[ "$(id -u 2>/dev/null || echo 1)" == "0" ]]; then
  mpi_root_args+=(--allow-run-as-root)
fi

version_out="$("$mpiexec" "${mpi_root_args[@]}" -n 1 "$pb" -v 2>&1 | tr -d '\r')" || {
  printf '%s\n' "$version_out" >&2
  die "pb_mpi -v failed under the packaged mpiexec"
}
[[ "$version_out" == *"pb_mpi version 1.9"* ]] || {
  printf '%s\n' "$version_out" >&2
  die "unexpected pb_mpi version output"
}

mpi_out="$("$mpiexec" "${mpi_root_args[@]}" -n 2 "$pb" -v 2>&1 | tr -d '\r')" || {
  printf '%s\n' "$mpi_out" >&2
  die "two-rank MPI launch failed"
}
[[ "$mpi_out" == *"pb_mpi version 1.9"* ]] || {
  printf '%s\n' "$mpi_out" >&2
  die "two-rank MPI run did not report the version"
}

direct_out="$("$pb" -v 2>&1 | tr -d '\r')" || {
  printf '%s\n' "$direct_out" >&2
  die "direct pb_mpi launch failed"
}
[[ "$direct_out" == *"pb_mpi version 1.9"* ]] || {
  printf '%s\n' "$direct_out" >&2
  die "direct pb_mpi run did not report the version"
}

log "PhyloBayes-MPI smoke test passed"
