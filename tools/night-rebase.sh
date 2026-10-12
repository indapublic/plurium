#!/bin/bash
# Moves the profile-tabs branch to a new Chromium stable tag and builds
# out/Release: fetch the tag -> rebase our commits onto it -> gclient sync ->
# night2.sh. The old branch is kept as profile-tabs-<old version>. Stops on any
# rebase conflict (the rebase is aborted, nothing else changes). Launch
# detached like night1.sh:
#   cd /Volumes/Workspace/chromium && nohup caffeinate -ims bash plurium/tools/night-rebase.sh 155.0.8059.40 \
#     </dev/null >> logs/night-rebase.log 2>&1 &
# JOBS (default 4) is passed on to night2.sh.
set -uo pipefail

NEW=${1:?usage: night-rebase.sh <new stable version>}
ROOT=/Volumes/Workspace/chromium
LOG_DIR="$ROOT/logs"
STATUS="$LOG_DIR/STATUS"
START_TS=$(date +%s)
mkdir -p "$LOG_DIR"

free_gb() { df -g "$ROOT" | awk 'NR==2 {print $4}'; }
stage() {
  local elapsed=$(( ($(date +%s) - START_TS) / 60 ))
  echo
  echo "=== [$(date '+%F %T')] (+${elapsed}m, free $(free_gb)G) $*"
  echo "$(date '+%F %T') (+${elapsed}m) $*" > "$STATUS"
}
fail() { stage "FAILED: $*"; exit 1; }
retry() {
  local n=0
  until "$@"; do
    n=$((n + 1))
    [ "$n" -ge 3 ] && return 1
    echo "--- retry $n/2 in 60s: $*"
    sleep 60
  done
}

export PATH="$ROOT/depot_tools:$PATH"
export DEPOT_TOOLS_METRICS=0
ulimit -n 65536 2>/dev/null || ulimit -n 10240 2>/dev/null || true

OLD=$(cat "$ROOT/STABLE_VERSION")
stage "1/4 checks ($OLD -> $NEW)"
[ "$OLD" != "$NEW" ] || fail "already on $NEW"
[ "$(free_gb)" -ge 40 ] || fail "only $(free_gb) GB free, need 40"
cd "$ROOT/src" || fail "cd src"
[ "$(git rev-parse --abbrev-ref HEAD)" = "profile-tabs" ] || fail "src is not on branch profile-tabs"
[ -z "$(git status --porcelain --untracked-files=no)" ] || fail "uncommitted changes in src"
git merge-base --is-ancestor "tags/$OLD" HEAD || fail "profile-tabs is not based on tags/$OLD"
git log --oneline "tags/$OLD..HEAD"

stage "2/4 fetch tags/$NEW"
retry git fetch origin "+refs/tags/$NEW:refs/tags/$NEW" || fail "git fetch $NEW"

stage "3/4 rebase onto tags/$NEW"
git branch -f "profile-tabs-$OLD" profile-tabs
if ! git rebase --onto "tags/$NEW" "tags/$OLD" profile-tabs; then
  git status --short | head -40
  git rebase --abort
  fail "rebase conflicts (aborted; profile-tabs is unchanged)"
fi
git log --oneline "tags/$NEW..HEAD"
echo "$NEW" > "$ROOT/STABLE_VERSION"

stage "4/4 gclient sync"
cd "$ROOT" || fail "cd root"
retry gclient sync -D --with_branch_heads --with_tags || fail "gclient sync"

stage "rebased on $NEW, building out/Release"
JOBS=${JOBS:-4} exec bash "$ROOT/plurium/tools/night2.sh"
