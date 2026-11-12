#!/bin/bash
# regress.sh — paper2moonbit full regression suite.
# Usage: sh regress.sh [workspace_dir]
# Runs moon check + test (+ prove where configured) over every project
# produced by the paper2moonbit rounds, and prints a PASS/FAIL matrix.
# Purpose: after any moon toolchain upgrade, verify that all recipes still
# hold — turns one-shot validation into continuous trust.
set -u

# Workspace: normalise to an absolute path up front. Each project is visited in
# its own subshell, but normalising here also makes error messages unambiguous
# and keeps a relative argument (".") working.
WS="${1:-$(pwd)}"
case "$WS" in
  /*) ;;
  *) WS="$(cd "$WS" 2>/dev/null && pwd)" || { echo "workspace not found: ${1:-$WS}" >&2; exit 2; } ;;
esac
[ -d "$WS" ] || { echo "workspace is not a directory: $WS" >&2; exit 2; }

MOON_VER=$(moon version 2>&1 | head -1)

# Private scratch dir. A fixed /tmp/reg_*.log path is a CWE-377 hazard: a
# pre-created symlink or FIFO at that name is followed by the shell's ">"
# redirection, which can clobber an unrelated file or capture build output.
# mktemp -d gives an unpredictable, 0700 directory owned by this user.
LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/paper2moonbit-regress.XXXXXX") || {
  echo "cannot create temp dir" >&2
  exit 2
}
chmod 700 "$LOG_DIR"

PROJECTS=(
  "projects/roaring-mbt"
  "projects/eliasfano-mbt"
  "projects/hyperloglog-mbt"
  "projects/xor16filter"
  "projects/ziplex-mbt"
  "projects/lifeguard-mbt"
  "projects/rqgm-mbt"
  "projects/crdt-mbt"
  "projects/bwt-mbt"
  "projects/chacha-mbt"
  "projects/chash-mbt"
  "projects/cms-mbt"
  "projects/codel-mbt"
  "projects/fpcomp-mbt"
  "projects/loglog-mbt"
  "projects/sais-mbt"
  "projects/skiplist-mbt"
)

# Keep the logs only when something failed; on a green run the directory is
# removed so no build output is left lying around on disk.
cleanup() {
  if [ "${overall:-1}" -eq 0 ] || [ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
    rm -rf "$LOG_DIR"
  else
    echo
    echo "logs kept in: $LOG_DIR"
  fi
}
trap cleanup EXIT INT TERM

echo "moon version: $MOON_VER"
echo "workspace:    $WS"
echo
printf "%-30s %-8s %-8s %-8s\n" "PROJECT" "CHECK" "TEST" "PROVE"
overall=0
PROVE_ENV_FAIL=""
for p in "${PROJECTS[@]}"; do
  dir="$WS/$p"
  if [ ! -f "$dir/moon.mod" ]; then
    printf "%-30s %-8s %-8s %-8s\n" "$p" "MISSING" "-" "-"
    overall=1
    continue
  fi
  # Every command runs in a subshell rooted at the project, so the loop's own
  # working directory is never mutated (a bare `cd` here used to break every
  # project after the first when the workspace argument was relative).
  # CHECK
  if ( cd "$dir" && moon check ) >"$LOG_DIR/check.log" 2>&1; then
    C=PASS
  else
    C=FAIL; overall=1
  fi
  # TEST
  if ( cd "$dir" && moon test ) >"$LOG_DIR/test.log" 2>&1; then
    T=PASS
  else
    T=FAIL; overall=1
  fi
  # PROVE: proofmodel package if present, else main package if proof-enabled
  # (no cache wipe: rm -rf on _build/verif trips the safe-delete guard; a
  # cached prove result is still a genuine pass)
  P="-"
  if [ -d "$dir/proofmodel" ]; then
    if ( cd "$dir" && moon prove proofmodel ) >"$LOG_DIR/prove.log" 2>&1; then
      P=PASS
    else
      P=FAIL; overall=1
      # `anomaly: Sys_error` means why3 could not perform a file operation
      # (e.g. rotating why3session.xml / .bak), not that a goal failed. The
      # proof may still hold; flag it so the summary can say how to clear it.
      if grep -q "anomaly: Sys_error" "$LOG_DIR/prove.log"; then
        P="FAIL*"
        PROVE_ENV_FAIL="$PROVE_ENV_FAIL${PROVE_ENV_FAIL:+ }$p"
      fi
    fi
  elif grep -q 'proof-enabled' "$dir/moon.pkg" 2>/dev/null || grep -q '^proof_enabled' "$dir/moon.pkg" 2>/dev/null; then
    if ( cd "$dir" && moon prove . ) >"$LOG_DIR/prove.log" 2>&1; then
      P=PASS
    else
      P=FAIL; overall=1
      if grep -q "anomaly: Sys_error" "$LOG_DIR/prove.log"; then
        P="FAIL*"
        PROVE_ENV_FAIL="$PROVE_ENV_FAIL${PROVE_ENV_FAIL:+ }$p"
      fi
    fi
  fi
  printf "%-30s %-8s %-8s %-8s\n" "$p" "$C" "$T" "$P"
done
echo
if [ "$overall" -eq 0 ]; then
  echo "OVERALL: ALL GREEN"
else
  echo "OVERALL: FAILURES PRESENT"
fi
if [ -n "$PROVE_ENV_FAIL" ]; then
  echo
  echo "* PROVE shows 'anomaly: Sys_error' for the package(s) below — that is a why3"
  echo "  file-operation failure inside _build/verif (e.g. it could not rotate"
  echo "  why3session.xml), not a goal that failed to prove. The proof may still"
  echo "  hold. Clear the session cache and re-run:"
  for p in $PROVE_ENV_FAIL; do
    echo "    rm -rf \"$WS/$p/_build/verif/.why3harness\""
  done
fi
exit $overall
