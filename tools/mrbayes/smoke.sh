#!/usr/bin/env bash
#
# Smoke-test the packaged MrBayes 3.2.8 + BEAGLE 4 build.
#
# Runs showbeagle and two fixed-seed MCMC chains with explicit BEAGLE thread
# counts (1 and 4). The initial log likelihood must match, which catches
# incorrect BEAGLE threading results.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

if [[ "$CYAN_PLATFORM" != windows || "$CYAN_ARCH" != x64 ]]; then
  log "mrbayes: skipping smoke test on $CYAN_PLATFORM $CYAN_ARCH"
  exit 0
fi

tool=mrbayes
pkg="$CYAN_BUILD/stage/$tool"
mb="$pkg/mb.exe"
[[ -x "$mb" ]] || die "missing packaged mb.exe: $mb"

version_out="$("$mb" -v 2>&1 | tr -d '\r')"
[[ "$version_out" == *"Version:   3.2.8"* ]] \
  || die "unexpected MrBayes version output"
[[ "$version_out" == *"Beagle"* ]] \
  || die "MrBayes was built without BEAGLE support"

smoke="$CYAN_BUILD/$tool/smoke"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/primates.nex" "$smoke/base.nex"

# --- BEAGLE resource / version check ---
cp "$smoke/base.nex" "$smoke/show.nex"
cat >> "$smoke/show.nex" <<'EOF'

begin mrbayes;
    set autoclose=yes nowarn=yes;
    showbeagle;
end;
EOF
(
  cd "$smoke"
  timeout 120 "$mb" show.nex > show.log 2>&1
) || {
  tail -n 40 "$smoke/show.log" >&2 || true
  die "showbeagle failed"
}
tr -d '\r' < "$smoke/show.log" > "$smoke/show.clean.log"
grep -q 'BEAGLE version: 4\.0\.0' "$smoke/show.clean.log" \
  || die "BEAGLE 4.0.0 was not loaded"
grep -q 'THREADING_CPP' "$smoke/show.clean.log" \
  || die "BEAGLE CPU threading was not reported"
grep -q 'VECTOR_SSE' "$smoke/show.clean.log" \
  || die "BEAGLE SSE/NEON plugin was not listed"

# --- fixed-seed MCMC with 1 and 4 BEAGLE threads ---
for threads in 1 4; do
  cp "$smoke/base.nex" "$smoke/run$threads.nex"
  cat >> "$smoke/run$threads.nex" <<EOF

begin mrbayes;
    set autoclose=yes nowarn=yes;
    set seed=12345 swapseed=54321;
    set beaglethreadcount=$threads;
    mcmc ngen=1000 samplefreq=100 printfreq=500 diagnfreq=1000 nruns=1 nchains=2;
end;
EOF
  (
    cd "$smoke"
    timeout 180 "$mb" "run$threads.nex" > "run$threads.log" 2>&1
  ) || {
    tail -n 50 "$smoke/run$threads.log" >&2 || true
    die "MCMC with beaglethreadcount=$threads failed"
  }
  tr -d '\r' < "$smoke/run$threads.log" > "$smoke/run$threads.clean.log"
  grep -q 'Initial log likelihoods' "$smoke/run$threads.clean.log" \
    || die "MCMC log has no initial likelihood (threads=$threads)"
done

ln1="$(grep -A2 'Initial log likelihoods' "$smoke/run1.clean.log" \
  | grep 'Chain 1' | awk '{print $4}' | head -n 1)"
ln4="$(grep -A2 'Initial log likelihoods' "$smoke/run4.clean.log" \
  | grep 'Chain 1' | awk '{print $4}' | head -n 1)"
[[ -n "$ln1" && "$ln1" == "$ln4" ]] \
  || die "threaded likelihood differs from single-threaded ($ln1 vs $ln4)"

log "MrBayes smoke test passed (threads 1/4, initial lnL $ln1)"
