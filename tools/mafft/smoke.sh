#!/usr/bin/env bash
#
# Smoke-test the packaged MAFFT 7.505 Windows x64 bash-min runtime.
#
# The YR-MPE plugin exposes six alignment modes, two direction-adjustment
# modes, Clustal output, reordering, gap penalties and explicit threading.
# Each case is run through the packaged mafft.bat, so the test also covers the
# MSYS2 path setup and the runtime whitelist.
#
# mafft.bat does not propagate MAFFT's exit status (it ends with `exit /b`),
# so every case validates the output itself.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/common.sh
source "$TOOL_DIR/../../scripts/common.sh"

tool=mafft
version="$(tr -d '[:space:]' < "$TOOL_DIR/VERSION")"
pkg="$CYAN_BUILD/stage/$tool"
smoke="$CYAN_BUILD/$tool/smoke"

[[ "$CYAN_PLATFORM-$CYAN_ARCH" == windows-x64 ]] \
  || die "MAFFT smoke test requires windows-x64"
[[ -f "$pkg/mafft.bat" ]] || die "missing packaged mafft.bat"
[[ -x "$pkg/usr/bin/bash.exe" ]] || die "missing packaged bash.exe"

rm -rf "$smoke"
mkdir -p "$smoke"
cp "$TOOL_DIR/examples/example.fa" "$pkg/smoke-input.fa"

# Reverse one record so --adjustdirection has something to correct.
awk '
function revcomp(s,  i,c,r) {
  r = ""
  for (i = length(s); i >= 1; i--) {
    c = toupper(substr(s, i, 1))
    if (c == "A") c = "T"
    else if (c == "T") c = "A"
    else if (c == "G") c = "C"
    else if (c == "C") c = "G"
    r = r c
  }
  return r
}
/^>beta$/ {
  print
  if ((getline line) > 0) print revcomp(line)
  next
}
{ print }
' "$pkg/smoke-input.fa" > "$pkg/smoke-reversed.fa"

run_case() {
  local tag="$1"
  shift
  ( cd "$pkg" && cmd //c ".\\mafft.bat $*" ) \
    > "$smoke/$tag.out" 2> "$smoke/$tag.err" || true
  if [[ ! -s "$smoke/$tag.out" ]]; then
    tail -n 30 "$smoke/$tag.err" >&2 || true
    die "MAFFT produced no output for $tag"
  fi
}

check_fasta() {
  local file="$1" expected="$2"
  awk -v expected="$expected" '
    /^>/ {
      if (n == 1) len = length(seq)
      else if (n > 1 && length(seq) != len) bad = 1
      n++; seq = ""; next
    }
    { gsub(/[ \t\r]/, ""); seq = seq $0 }
    END {
      if (n == 1) len = length(seq)
      else if (n > 1 && length(seq) != len) bad = 1
      if (n != expected || len == 0) bad = 1
      exit bad
    }
  ' "$file" || die "invalid or empty FASTA output: $file"
}

check_clustal() {
  local file="$1" expected="$2"
  awk -v expected="$expected" '
    /^CLUSTAL/ { header = 1; next }
    /^[^[:space:]]/ { names[$1] = 1 }
    END { exit (header && length(names) == expected) ? 0 : 1 }
  ' "$file" || die "invalid Clustal output: $file"
}

version_out="$(
  cd "$pkg"
  cmd //c ".\\mafft.bat --version" 2>&1 | tr -d '\r'
)" || true
[[ "$version_out" == *"v$version"* ]] \
  || die "unexpected MAFFT version output: $version_out"

log "Running MAFFT alignment modes"
run_case auto --auto smoke-input.fa
check_fasta "$smoke/auto.out" 5

run_case default smoke-input.fa
check_fasta "$smoke/default.out" 5

run_case localpair --maxiterate 1000 --localpair smoke-input.fa
check_fasta "$smoke/localpair.out" 5

run_case genafpair --maxiterate 1000 --genafpair smoke-input.fa
check_fasta "$smoke/genafpair.out" 5

run_case globalpair --maxiterate 1000 --globalpair smoke-input.fa
check_fasta "$smoke/globalpair.out" 5

run_case retree1 --retree 1 smoke-input.fa
check_fasta "$smoke/retree1.out" 5

log "Running MAFFT direction, output and threading options"
run_case direction --auto --adjustdirection smoke-reversed.fa
check_fasta "$smoke/direction.out" 5
grep -q '^>_R_' "$smoke/direction.out" \
  || die "--adjustdirection did not mark the reversed record"

run_case direction_accurate --auto --adjustdirectionaccurately smoke-reversed.fa
check_fasta "$smoke/direction_accurate.out" 5
grep -q '^>_R_' "$smoke/direction_accurate.out" \
  || die "--adjustdirectionaccurately did not mark the reversed record"

run_case clustal --auto --clustalout smoke-input.fa
check_clustal "$smoke/clustal.out" 5

run_case reorder --auto --reorder smoke-input.fa
check_fasta "$smoke/reorder.out" 5

run_case threads --auto --thread 2 smoke-input.fa
check_fasta "$smoke/threads.out" 5
[[ "$(sha256_file "$smoke/auto.out")" == "$(sha256_file "$smoke/threads.out")" ]] \
  || die "two-thread MAFFT output differs from single-thread output"

run_case advanced --auto --op 1.5 --ep 0.1 --maxiterate 2 smoke-input.fa
check_fasta "$smoke/advanced.out" 5

log "MAFFT smoke test passed (12 cases, bash-min runtime)"
