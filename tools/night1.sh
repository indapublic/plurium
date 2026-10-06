#!/bin/bash
# Night 1: depot_tools -> fetch chromium (full history) -> checkout stable tag on
# branch profile-tabs -> gclient sync -> baseline build out/Default (no changes).
#
# Idempotent: safe to re-run after a failure or interruption, every stage skips
# work that is already done. Launch detached, e.g.:
#   cd /Volumes/Workspace/chromium && nohup caffeinate -ims bash plurium/tools/night1.sh \
#     </dev/null >> logs/night1.log 2>&1 &
set -uo pipefail

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

stage "1/6 environment"
[ "$(xcode-select -p)" = "/Applications/Xcode.app/Contents/Developer" ] ||
  fail "xcode-select does not point at /Applications/Xcode.app"
xcodebuild -version
xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q 'Status: installed' ||
  fail "Metal Toolchain missing (Xcode 26+): run xcodebuild -downloadComponent MetalToolchain"
if [ ! -d "$ROOT/src/.git" ]; then
  [ "$(free_gb)" -ge 150 ] || fail "only $(free_gb) GB free, need 150"
else
  [ "$(free_gb)" -ge 40 ] || fail "only $(free_gb) GB free, need 40 to build"
fi
ulimit -n 65536 2>/dev/null || ulimit -n 10240 2>/dev/null || true
echo "open files limit: $(ulimit -n)"

stage "2/6 depot_tools"
if [ ! -d "$ROOT/depot_tools/.git" ]; then
  retry git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
    "$ROOT/depot_tools" || fail "depot_tools clone"
fi
export PATH="$ROOT/depot_tools:$PATH"
export DEPOT_TOOLS_METRICS=0

stage "3/6 stable version"
if [ -s "$ROOT/STABLE_VERSION" ]; then
  VER=$(cat "$ROOT/STABLE_VERSION")
else
  VER=$(curl -fsS 'https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Mac&num=1' |
    python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["version"])') || fail "chromiumdash"
  echo "$VER" > "$ROOT/STABLE_VERSION"
fi
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "bad version '$VER'"
echo "Stable for Mac: $VER"

stage "4/6 fetch chromium (full history)"
cd "$ROOT" || fail "cd $ROOT"
fetch_failed=0
if [ ! -f "$ROOT/.gclient" ]; then
  fetch --nohooks chromium || fetch_failed=1
fi
if [ ! -d "$ROOT/src/.git" ] || [ "$fetch_failed" = 1 ]; then
  echo "--- resuming checkout with gclient sync --nohooks"
  retry gclient sync --nohooks || fail "initial gclient sync"
fi

stage "5/6 checkout tags/$VER on profile-tabs + gclient sync"
cd "$ROOT/src" || fail "cd src"
if ! git rev-parse -q --verify "refs/tags/$VER" >/dev/null; then
  retry git fetch origin "+refs/tags/$VER:refs/tags/$VER" || fail "fetch tag $VER"
fi
if git rev-parse -q --verify refs/heads/profile-tabs >/dev/null; then
  git checkout profile-tabs || fail "checkout profile-tabs"
else
  git checkout -b profile-tabs "tags/$VER" || fail "checkout -b profile-tabs tags/$VER"
fi
git log -1 --format='HEAD: %H %s'
retry gclient sync -D --with_branch_heads --with_tags || fail "gclient sync"

stage "6/6 gn gen + autoninja out/Default chrome"
mkdir -p out/Default
ARGS='is_debug = false
is_component_build = true
symbol_level = 0
target_cpu = "arm64"
proprietary_codecs = true
ffmpeg_branding = "Chrome"'
if [ "$(cat out/Default/args.gn 2>/dev/null)" != "$ARGS" ]; then
  printf '%s\n' "$ARGS" > out/Default/args.gn
fi
gn gen out/Default || fail "gn gen"
# One retry covers transient failures (e.g. a compiler killed under memory
# pressure); a real compile error fails twice and stops here.
autoninja -C out/Default chrome || autoninja -C out/Default chrome || fail "build"

ls -la out/Default/Chromium.app/Contents/MacOS/ || fail "Chromium.app missing"
stage "DONE night1: $VER built in out/Default"
