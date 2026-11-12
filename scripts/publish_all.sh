#!/bin/bash
# publish_all.sh — bump every paper2moonbit package by one patch version and
# publish the set to mooncakes.io in a single pass.
#
# Usage:
#   sh scripts/publish_all.sh            # dry run: print the plan, touch nothing
#   sh scripts/publish_all.sh --apply    # bump -> check -> test -> publish
#
# Why a script: the 17 packages are released together, so a fixed publish order
# and one version bump keep them coherent. Order does not matter technically —
# no package in this repo depends on another — but a single pass keeps the
# version table readable in the commit message.
#
# Safety:
#   * --apply refuses to run on a dirty worktree, so the bump is an isolated
#     commit and `git checkout -- projects` is always a valid rollback.
#   * each package must pass `moon check` and `moon test` before it is published
#   * the first publish is done with `--dry-run` to surface auth/quota problems
#     before anything is irreversibly released
#   * publish output goes to a private mktemp dir (CWE-377), kept only on failure
set -u

MODE=dry
case "${1:-}" in
  "")        ;;
  --apply)   MODE=apply ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)         echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || { echo "cannot locate repo root" >&2; exit 2; }
cd "$ROOT" || exit 2

PROJECTS=(
  "projects/bwt-mbt"
  "projects/chacha-mbt"
  "projects/chash-mbt"
  "projects/cms-mbt"
  "projects/codel-mbt"
  "projects/crdt-mbt"
  "projects/eliasfano-mbt"
  "projects/fpcomp-mbt"
  "projects/hyperloglog-mbt"
  "projects/lifeguard-mbt"
  "projects/loglog-mbt"
  "projects/roaring-mbt"
  "projects/rqgm-mbt"
  "projects/sais-mbt"
  "projects/skiplist-mbt"
  "projects/xor16filter"
  "projects/ziplex-mbt"
)

command -v moon >/dev/null 2>&1 || { echo "moon not found in PATH" >&2; exit 2; }

LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/paper2moonbit-publish.XXXXXX") || {
  echo "cannot create temp dir" >&2
  exit 2
}
chmod 700 "$LOG_DIR"

PUBLISHED=""
FAILED=""
KEEP_LOGS=0
cleanup() {
  if [ "$KEEP_LOGS" -eq 0 ]; then
    rm -rf "$LOG_DIR"
  else
    echo
    echo "logs kept in: $LOG_DIR"
  fi
}
trap cleanup EXIT INT TERM

echo "moon:  $(moon version 2>&1 | head -1)"
echo "root:  $ROOT"
echo "mode:  $MODE"
echo

# --- plan (read-only): project | package | current | next -------------------
PLAN=$(python3 - "$ROOT" "${PROJECTS[@]}" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
for d in sys.argv[2:]:
    p = root / d / "moon.mod"
    if not p.is_file():
        print(f"{d}|?|MISSING|-")
        continue
    t = p.read_text(encoding="utf-8")
    v = re.search(r'(?m)^version\s*=\s*"(\d+)\.(\d+)\.(\d+)"', t)
    n = re.search(r'(?m)^name\s*=\s*"([^"]+)"', t)
    name = n.group(1) if n else "?"
    if not v:
        print(f"{d}|{name}|MISSING|-")
    else:
        cur = f"{v.group(1)}.{v.group(2)}.{v.group(3)}"
        nxt = f"{v.group(1)}.{v.group(2)}.{int(v.group(3)) + 1}"
        print(f"{d}|{name}|{cur}|{nxt}")
PY
) || { echo "failed to read versions" >&2; exit 2; }

printf "%-18s %-28s %-10s %-10s\n" PROJECT PACKAGE CURRENT NEXT
printf "%-18s %-28s %-10s %-10s\n" ------- ------- ------- ----
bad=0
while IFS='|' read -r d pkg cur nxt; do
  printf "%-18s %-28s %-10s %-10s\n" "${d#projects/}" "$pkg" "$cur" "$nxt"
  [ "$cur" = "MISSING" ] && bad=1
done <<<"$PLAN"
echo

if [ "$bad" -ne 0 ]; then
  echo "ABORT: at least one package has no readable version field." >&2
  exit 1
fi

if [ "$MODE" = "dry" ]; then
  echo "Dry run — nothing was modified or published."
  echo "Re-run with --apply to bump and publish."
  exit 0
fi

# --- apply ----------------------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ABORT: not a git worktree — the rollback path (git checkout -- projects) would not exist." >&2
  exit 2
}
if [ -n "$(git status --porcelain)" ]; then
  echo "ABORT: worktree is not clean. Commit or stash first so the bump stays isolated." >&2
  git status --short >&2
  exit 2
fi
echo "moon login (credentials are read from the local toolchain config)"
echo

# bump every moon.mod, in place
python3 - "$ROOT" "${PROJECTS[@]}" <<'PY' || { echo "ABORT: version bump failed" >&2; exit 2; }
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
for d in sys.argv[2:]:
    p = root / d / "moon.mod"
    t = p.read_text(encoding="utf-8")
    m = re.search(r'(?m)^version\s*=\s*"(\d+)\.(\d+)\.(\d+)"', t)
    if not m:
        sys.exit(f"no version in {p}")
    nxt = f"{m.group(1)}.{m.group(2)}.{int(m.group(3)) + 1}"
    t = t[:m.start()] + f'version = "{nxt}"' + t[m.end():]
    p.write_text(t, encoding="utf-8")
    print(f"bumped {p.parent.name} -> {nxt}")
PY

i=0
while IFS='|' read -r d pkg cur nxt; do
  i=$((i + 1))
  name="${d#projects/}"
  printf "[%2d/%d] %-18s " "$i" "${#PROJECTS[@]}" "$name"

  # gate: the package must compile and its tests must pass before release
  if ! ( cd "$d" && moon check ) >"$LOG_DIR/${name}_check.log" 2>&1; then
    printf "CHECK-FAIL\n"
    FAILED="$FAILED ${name}:check"
    KEEP_LOGS=1
    break
  fi
  if ! ( cd "$d" && moon test ) >"$LOG_DIR/${name}_test.log" 2>&1; then
    printf "TEST-FAIL\n"
    FAILED="$FAILED ${name}:test"
    KEEP_LOGS=1
    break
  fi

  # first package: validate the publication (auth, metadata, version clash)
  # without creating a release, so we learn about problems before releasing.
  if [ "$i" -eq 1 ]; then
    if ! ( cd "$d" && moon publish --dry-run ) >"$LOG_DIR/${name}_dryrun.log" 2>&1; then
      printf "PUBLISH-DRYRUN-FAIL\n"
      FAILED="$FAILED ${name}:dryrun"
      KEEP_LOGS=1
      echo "  see: $LOG_DIR/${name}_dryrun.log" >&2
      tail -5 "$LOG_DIR/${name}_dryrun.log" >&2
      break
    fi
  fi

  if ( cd "$d" && moon publish ) >"$LOG_DIR/${name}_publish.log" 2>&1; then
    printf "PUBLISHED %s\n" "$nxt"
    PUBLISHED="$PUBLISHED ${name}:${nxt}"
  else
    printf "PUBLISH-FAIL\n"
    FAILED="$FAILED ${name}:publish"
    KEEP_LOGS=1
    tail -5 "$LOG_DIR/${name}_publish.log" >&2
    break
  fi
done <<<"$PLAN"

echo
echo "----------------------------------------"
echo "published:${PUBLISHED:- none}"
if [ -n "$FAILED" ]; then
  echo "failed:   $FAILED"
  echo
  echo "Rollback (nothing was published for the failed package):"
  echo "  git checkout -- projects   # restore all moon.mod versions"
  exit 1
fi

echo
echo "All ${#PROJECTS[@]} packages published. Suggested commit:"
echo "  git add -A && git commit -m \"chore: bump 17 packages to patch releases\" && git push"
exit 0
