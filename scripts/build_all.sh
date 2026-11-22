#!/usr/bin/env bash
#
# Build every tool under tools/<name>/ that provides a build.sh.
#
# CYAN_TOOLS selects a subset, for example:
#   CYAN_TOOLS=lsd2 bash scripts/build_all.sh
#   CYAN_TOOLS="lsd2 mafft" bash scripts/build_all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

scripts="$(cyan_tool_scripts build)" || exit 1
if [[ -z "$scripts" ]]; then
  log "No selected tool supports $CYAN_PLATFORM $CYAN_ARCH; nothing to build"
  exit 0
fi

# tools/<name>/DEPENDS lists other CYAN tools that must be built first. Only
# dependencies that are also selected here are ordered; a tool invoked on its
# own builds any missing dependency itself.
is_selected() {
  local tool="$1"
  tr -d '\r' <<< "$scripts" | grep -Fqx "$CYAN_ROOT/tools/$tool/build.sh"
}

is_built() {
  case " $built " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

pending="$scripts"
built=""
while [[ -n "${pending//[$'\n']/}" ]]; do
  progress=false
  next_pending=""
  while IFS= read -r build; do
    [[ -n "$build" ]] || continue
    tool_dir="$(dirname "$build")"
    tool="$(basename "$tool_dir")"

    if is_built "$tool"; then
      continue
    fi

    ready=true
    if [[ -f "$tool_dir/DEPENDS" ]]; then
      while IFS= read -r dep; do
        dep="${dep//$'\r'/}"
        [[ -n "$dep" ]] || continue
        if is_selected "$dep" && ! is_built "$dep"; then
          ready=false
          break
        fi
      done < "$tool_dir/DEPENDS"
    fi

    if [[ "$ready" == false ]]; then
      next_pending+="$build"$'\n'
      continue
    fi

    log "Building $tool ($CYAN_PLATFORM_LABEL $CYAN_ARCH, release $CYAN_RELEASE)"
    (
      cd "$tool_dir"
      bash ./build.sh
    )
    built="$built $tool"
    progress=true
  done <<< "$pending"

  [[ "$progress" == true ]] || die "circular DEPENDS among: $(tr '\n' ' ' <<< "$pending")"
  pending="$next_pending"
done

log "Build complete: $(ls -1 "$CYAN_DIST" | tr '\n' ' ')"
