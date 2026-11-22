#!/usr/bin/env bash
#
# Smoke-test the frozen OrthoFinder build.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=orthofinder3
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/orthofinder$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged OrthoFinder: $bin"
for native in diamond mcl; do
  [[ -x "$pkg/bin/$native$CYAN_EXE" ]] \
    || die "missing bundled native tool: bin/$native$CYAN_EXE"
done

rm -rf "$smoke"
mkdir -p "$smoke/input"
cp "$TOOL_DIR/examples/species_a.fa" "$TOOL_DIR/examples/species_b.fa" "$smoke/input/"

help_out="$("$bin" -h 2>&1 | tr -d '\r')" || true
grep -q "OrthoFinder version $version" <<< "$help_out" \
  || die "unexpected OrthoFinder version output: $(head -n 2 <<< "$help_out")"

# Orthogroup inference exercises DIAMOND, MCL and the frozen numpy/scipy
# stack. This is the path YR-MPE uses.
(
  cd "$smoke"
  "$bin" -f input -o out-og -t 2 -S diamond -og -X > og.log 2>&1
) || {
  tail -n 40 "$smoke/og.log" >&2 || true
  die "OrthoFinder -og run failed"
}
og_tsv="$(find "$smoke/out-og" -name Orthogroups.tsv -print -quit)"
[[ -n "$og_tsv" && -s "$og_tsv" ]] || die "OrthoFinder produced no Orthogroups.tsv"

# FAMSA is not OrthoFinder's default MSA method; check that the bundled
# config entry and binary are wired up.
if [[ -x "$pkg/bin/famsa$CYAN_EXE" ]]; then
  (
    cd "$smoke"
    "$bin" -f input -o out-msa -t 2 -S diamond -M msa -A famsa -oa \
      > msa.log 2>&1
  ) || {
    tail -n 40 "$smoke/msa.log" >&2 || true
    die "OrthoFinder FAMSA alignment run failed"
  }
  msa_dir="$(find "$smoke/out-msa" -type d -name MultipleSequenceAlignments -print -quit)"
  [[ -n "$msa_dir" ]] || die "OrthoFinder produced no MultipleSequenceAlignments"
  [[ -n "$(find "$msa_dir" -type f -print -quit)" ]] \
    || die "FAMSA produced no alignment files"
fi

log "OrthoFinder smoke test passed (diamond + MCL + frozen Python)"
