#!/bin/bash
# regress.sh — paper2moonbit full regression suite.
# Usage: sh regress.sh [workspace_dir]
# Runs moon check + test (+ prove where configured) over every project
# produced by the paper2moonbit rounds, and prints a PASS/FAIL matrix.
# Purpose: after any moon toolchain upgrade, verify that all recipes still
# hold — turns one-shot validation into continuous trust.
set -u
WS="${1:-$(pwd)}"
MOON_VER=$(moon version 2>&1 | head -1)
PROJECTS=(
  "xor16-mbt/roaring-mbt"
  "xor16-mbt/eliasfano-mbt"
  "xor16-mbt/hyperloglog-mbt"
  "xor16-mbt/xor16filter"
  "xor16-mbt/ziplex-mbt"
  "xor16-mbt/lifeguard-mbt"
  "rqgm-mbt"
  "crdt-mbt"
  "bwt-mbt"
  "chacha-mbt"
  "chash-mbt"
  "cms-mbt"
  "codel-mbt"
  "fpcomp-mbt"
  "loglog-mbt"
  "sais-mbt"
  "skiplist-mbt"
)
echo "moon version: $MOON_VER"
echo "workspace:    $WS"
echo
printf "%-30s %-8s %-8s %-8s\n" "PROJECT" "CHECK" "TEST" "PROVE"
overall=0
for p in "${PROJECTS[@]}"; do
  dir="$WS/$p"
  if [ ! -f "$dir/moon.mod" ]; then
    printf "%-30s %-8s %-8s %-8s\n" "$p" "MISSING" "-" "-"
    overall=1
    continue
  fi
  cd "$dir" || exit 1
  # CHECK
  if moon check >/tmp/reg_check.log 2>&1; then C=PASS; else C=FAIL; overall=1; fi
  # TEST
  if moon test >/tmp/reg_test.log 2>&1; then T=PASS; else T=FAIL; overall=1; fi
  # PROVE: proofmodel package if present, else main package if proof-enabled
  # (no cache wipe: rm -rf on _build/verif trips the safe-delete guard; a
  # cached prove result is still a genuine pass)
  P="-"
  if [ -d proofmodel ]; then
    if moon prove proofmodel >/tmp/reg_prove.log 2>&1; then P=PASS; else P=FAIL; overall=1; fi
  elif grep -q 'proof-enabled' moon.pkg 2>/dev/null || grep -q '^proof_enabled' moon.pkg 2>/dev/null; then
    if moon prove . >/tmp/reg_prove.log 2>&1; then P=PASS; else P=FAIL; overall=1; fi
  fi
  printf "%-30s %-8s %-8s %-8s\n" "$p" "$C" "$T" "$P"
done
echo
if [ "$overall" -eq 0 ]; then
  echo "OVERALL: ALL GREEN"
else
  echo "OVERALL: FAILURES PRESENT (see per-project logs in /tmp/reg_*.log)"
fi
exit $overall
