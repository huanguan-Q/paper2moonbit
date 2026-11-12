#!/bin/bash
# backend_matrix.sh - differential testing across MoonBit backends.
# Usage: sh scripts/backend_matrix.sh [workspace_dir]
set -u

# Normalise the workspace to an absolute path (see regress.sh for rationale).
WS="${1:-$(pwd)}"
case "$WS" in
  /*) ;;
  *) WS="$(cd "$WS" 2>/dev/null && pwd)" || { echo "workspace not found: ${1:-$WS}" >&2; exit 2; } ;;
esac
[ -d "$WS" ] || { echo "workspace is not a directory: $WS" >&2; exit 2; }

# Private scratch dir — fixed /tmp/bm_*.log names are a CWE-377 hazard
# (pre-created symlink or FIFO is followed by ">" redirection).
LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/paper2moonbit-matrix.XXXXXX") || {
  echo "cannot create temp dir" >&2
  exit 2
}
chmod 700 "$LOG_DIR"

PROJECTS=(
  "projects/chacha-mbt"
  "projects/cms-mbt"
  "projects/loglog-mbt"
  "projects/chash-mbt"
  "projects/sais-mbt"
  "projects/codel-mbt"
  "projects/fpcomp-mbt"
  "projects/skiplist-mbt"
  "projects/crdt-mbt"
  "projects/bwt-mbt"
  "projects/roaring-mbt"
  "projects/eliasfano-mbt"
  "projects/hyperloglog-mbt"
  "projects/xor16filter"
  "projects/ziplex-mbt"
  "projects/lifeguard-mbt"
  "projects/rqgm-mbt"
)
TARGETS=(wasm wasm-gc js native)

cleanup() {
  if [ "${overall:-1}" -eq 0 ] || [ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
    rm -rf "$LOG_DIR"
  else
    echo
    echo "logs kept in: $LOG_DIR"
  fi
}
trap cleanup EXIT INT TERM

printf "%-24s" "PROJECT"
for t in "${TARGETS[@]}"; do printf "%-9s" "$t"; done
echo
overall=0
NA_LIST=""
for p in "${PROJECTS[@]}"; do
  dir="$WS/$p"
  name="${p#projects/}"
  printf "%-24s" "$name"
  # A missing project is a failure, not a silent skip — otherwise a moved or
  # renamed project makes the matrix print "ALL CONSISTENT" while testing
  # nothing.
  if [ ! -f "$dir/moon.mod" ]; then
    printf "%-9s" "MISSING"
    echo
    overall=1
    continue
  fi
  for t in "${TARGETS[@]}"; do
    log="$LOG_DIR/${name}_$t.log"
    # Subshell keeps the loop's cwd intact for every following project.
    if ( cd "$dir" && moon test --target "$t" ) >"$log" 2>&1; then
      # `moon test` exits 0 with "no test entry found / Total tests: 0" when a
      # target is not exercisable (e.g. supported_targets excludes it). Counting
      # that as PASS turns the matrix into a false-green, so require a non-zero
      # test count before claiming the target was covered.
      n=$(sed -n 's/.*Total tests: \([0-9][0-9]*\),.*/\1/p' "$log" | tail -1)
      n=${n:-0}
      if [ "$n" -eq 0 ]; then
        printf "%-9s" "N/A"
        NA_LIST="$NA_LIST ${name}:${t}"
      else
        printf "%-9s" "PASS"
      fi
    else
      printf "%-9s" "FAIL"
      overall=1
    fi
  done
  echo
done
echo
if [ "$overall" -eq 0 ]; then
  echo "BACKEND MATRIX: ALL CONSISTENT"
  [ -n "$NA_LIST" ] && echo "coverage: not exercised (0 tests ran) →$NA_LIST"
else
  echo "BACKEND MATRIX: DIVERGENCE DETECTED"
fi
exit $overall
