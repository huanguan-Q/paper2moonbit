#!/bin/bash
# backend_matrix.sh - differential testing across MoonBit backends.
set -u
WS="${1:-$(pwd)}"
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
printf "%-24s" "PROJECT"
for t in "${TARGETS[@]}"; do printf "%-9s" "$t"; done
echo
overall=0
for p in "${PROJECTS[@]}"; do
  dir="$WS/$p"
  printf "%-24s" "${p#projects/}"
  if [ ! -f "$dir/moon.mod" ]; then printf "%-9s" "MISSING"; echo; continue; fi
  cd "$dir" || exit 1
  for t in "${TARGETS[@]}"; do
    if moon test --target "$t" >"/tmp/bm_$(basename $p)_$t.log" 2>&1; then
      printf "%-9s" "PASS"
    else
      printf "%-9s" "FAIL"
      overall=1
    fi
  done
  echo
done
echo
[ "$overall" -eq 0 ] && echo "BACKEND MATRIX: ALL CONSISTENT" || echo "BACKEND MATRIX: DIVERGENCE DETECTED"
exit $overall
