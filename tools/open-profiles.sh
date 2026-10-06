#!/bin/bash
# Starts the test build and opens one window for each of the 4 seeded test
# profiles (see seed-profiles.py). Browser log: $LOG (default
# /Volumes/Workspace/chromium/logs/run.log). Honors OUT and USER_DATA_DIR.
TOOLS=$(cd "$(dirname "$0")" && pwd)
LOG=${LOG:-/Volumes/Workspace/chromium/logs/run.log}
URL_BASE=${URL_BASE:-}

nohup "$TOOLS/run-test.sh" --profile-directory=Default ${URL_BASE:+"$URL_BASE?Alpha"} \
  > "$LOG" 2>&1 &
for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:9222/json/version > /dev/null 2>&1 && break
  sleep 1
done
sleep 3
for pair in "Profile 1:Bravo" "Profile 2:Charlie" "Profile 3:Delta"; do
  "$TOOLS/run-test.sh" --profile-directory="${pair%%:*}" \
    ${URL_BASE:+"$URL_BASE?${pair##*:}"} > /dev/null 2>&1
  sleep 4
done
sleep 2
grep -a 'profile tabs' "$LOG" | sed 's/.*profile_tabs_mac.mm:[0-9]*\] //'
