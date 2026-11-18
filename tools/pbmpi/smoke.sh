#!/usr/bin/env bash
#
# Smoke-test PhyloBayes-MPI: all five programs exist, pb_mpi reports 1.9,
# and the binary runs under a two-rank MPI launch.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=pbmpi
build="$CYAN_BUILD/$tool"
bin="$build/bin"

for prog in pb_mpi readpb_mpi tracecomp bpcomp cvrep; do
  [[ -x "$bin/$prog$CYAN_EXE" ]] \
    || die "missing binary: $bin/$prog$CYAN_EXE (run build.sh first)"
done

if [[ "$CYAN_PLATFORM" == windows ]]; then
  mpiexec="$(cyan_mpiexec)"
else
  mpiexec="$(command -v mpiexec || true)"
fi
[[ -n "$mpiexec" ]] || die "mpiexec not found; install the MPI runtime"

# OpenMPI refuses to start more ranks than slots on small runners; this
# variable is harmless for MPICH and MS-MPI.
export OMPI_MCA_rmaps_base_oversubscribe=1

version_out="$("$mpiexec" -n 1 "$bin/pb_mpi$CYAN_EXE" -v 2>&1 | tr -d '\r')" || {
  printf '%s\n' "$version_out" >&2
  die "pb_mpi -v failed under mpiexec"
}
[[ "$version_out" == *"pb_mpi version 1.9"* ]] || {
  printf '%s\n' "$version_out" >&2
  die "unexpected pb_mpi version output"
}

mpi_out="$("$mpiexec" -n 2 "$bin/pb_mpi$CYAN_EXE" -v 2>&1 | tr -d '\r')" || {
  printf '%s\n' "$mpi_out" >&2
  die "two-rank MPI launch failed"
}
[[ "$mpi_out" == *"pb_mpi version 1.9"* ]] || {
  printf '%s\n' "$mpi_out" >&2
  die "two-rank MPI run did not report the version"
}

log "PhyloBayes-MPI smoke test passed"
