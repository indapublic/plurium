#!/bin/bash
# Night 2: daily-use Release build out/Release (non-component) of the
# profile-tabs branch. Idempotent; launch detached like night1.sh:
#   cd /Volumes/Workspace/chromium && nohup caffeinate -ims bash plurium/tools/night2.sh \
#     </dev/null >> logs/night2.log 2>&1 &
# With JOBS=4 in front of nohup if the Mac runs out of memory (heavy swapping).
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

export PATH="$ROOT/depot_tools:$PATH"
export DEPOT_TOOLS_METRICS=0
ulimit -n 65536 2>/dev/null || ulimit -n 10240 2>/dev/null || true

stage "1/2 checks"
xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q 'Status: installed' ||
  fail "Metal Toolchain missing (Xcode 26+): run xcodebuild -downloadComponent MetalToolchain"
[ "$(free_gb)" -ge 30 ] || fail "only $(free_gb) GB free, need 30"
cd "$ROOT/src" || fail "cd src"
[ "$(git rev-parse --abbrev-ref HEAD)" = "profile-tabs" ] || fail "src is not on branch profile-tabs"
git log --oneline -5

stage "2/2 gn gen + autoninja out/Release chrome"
mkdir -p out/Release
ARGS='is_debug = false
is_component_build = false
symbol_level = 0
dcheck_always_on = false
target_cpu = "arm64"
proprietary_codecs = true
ffmpeg_branding = "Chrome"'
if [ "$(cat out/Release/args.gn 2>/dev/null)" != "$ARGS" ]; then
  printf '%s\n' "$ARGS" > out/Release/args.gn
fi
gn gen out/Release || fail "gn gen"
# JOBS=N limits parallel compiles (fewer jobs = less RAM; useful on 16 GB).
J=${JOBS:+-j $JOBS}
autoninja -C out/Release chrome $J || autoninja -C out/Release chrome $J || fail "build"

ls -la out/Release/Chromium.app/Contents/MacOS/ || fail "Chromium.app missing"
stage "DONE night2: out/Release built"
