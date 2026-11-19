#!/usr/bin/env bash
#
# Smoke-test the DIAMOND build with the OrthoFinder search workflow:
# makedb, blastp, and compressed tabular output.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=diamond
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
bin="$pkg/diamond$CYAN_EXE"
smoke="$CYAN_BUILD/$tool/smoke"

[[ -x "$bin" ]] || die "missing packaged DIAMOND: $bin"
rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$smoke/example.fa"

version_out="$("$bin" version 2>&1 | tr -d '\r' | head -n 1)"
[[ "$version_out" == *"$version"* ]] \
  || die "unexpected DIAMOND version output: $version_out"

(
  cd "$smoke"
  "$bin" makedb --ignore-warnings --in example.fa -d example
) > "$smoke/makedb.log" 2>&1 || {
  tail -n 30 "$smoke/makedb.log" >&2 || true
  die "DIAMOND makedb failed"
}

(
  cd "$smoke"
  "$bin" blastp --ignore-warnings -d example -q example.fa \
    -o hits.tsv --more-sensitive -p 1 --quiet -e 0.001 --compress 1
) > "$smoke/blastp.log" 2>&1 || {
  tail -n 30 "$smoke/blastp.log" >&2 || true
  die "DIAMOND blastp failed"
}

[[ -s "$smoke/hits.tsv.gz" ]] || die "DIAMOND did not write hits.tsv.gz"
gzip -t "$smoke/hits.tsv.gz" || die "DIAMOND output is not valid gzip"
hits="$(gzip -dc "$smoke/hits.tsv.gz" | wc -l | tr -d '[:space:]')"
[[ "$hits" -gt 0 ]] || die "DIAMOND produced no hits"
gzip -dc "$smoke/hits.tsv.gz" | grep -q '^alpha' \
  || die "DIAMOND output has no alpha query hit"

log "DIAMOND smoke test passed ($version, makedb + blastp, $hits hits)"
