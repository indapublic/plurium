#!/bin/bash
# Launches the local build with an isolated user data dir (never the real
# Chrome/Chromium profile). Extra arguments are passed through, e.g.
#   plurium/tools/run-test.sh --profile-directory="Profile 2"
# OUT selects the build dir (default out/Default, or OUT=out/Release);
# USER_DATA_DIR the profile dir (default /tmp/chromium-test).
# A second call while the browser runs opens a window in the running process.
OUT=${OUT:-out/Default}
USER_DATA_DIR=${USER_DATA_DIR:-/tmp/chromium-test}
APP="/Volumes/Workspace/chromium/src/$OUT/Chromium.app/Contents/MacOS/Chromium"
exec "$APP" \
  --user-data-dir="$USER_DATA_DIR" \
  --use-mock-keychain \
  --no-first-run \
  --no-default-browser-check \
  --remote-debugging-port=9222 \
  --enable-logging=stderr \
  --vmodule=profile_tabs_mac=1 \
  "$@"
