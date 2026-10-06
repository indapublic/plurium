#!/bin/bash
# Automated part of the profile-tabs checklist. Uses a fresh test profile dir
# under /tmp and a local test page; never touches a real browser profile.
# Usage: OUT=out/Release plurium/tools/checklist.sh   (default out/Default)
# The browser must not be running. Prints PASS/FAIL per check.
set -u
TOOLS=$(cd "$(dirname "$0")" && pwd)
export OUT=${OUT:-out/Default}
export USER_DATA_DIR=/tmp/chromium-test-check-$(date +%s)
LOGS=/Volumes/Workspace/chromium/logs
LOG1=$LOGS/check-run1.log
LOG2=$LOGS/check-run2.log
SITE=/tmp/chromium-test-site
CDP="node $TOOLS/cdp.mjs"
failures=0

pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; failures=$((failures + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }
tabs_log() { grep -a 'profile tabs' "$1" | sed 's/.*profile_tabs_mac.mm:[0-9]*\] //'; }
alive() { curl -fsS http://127.0.0.1:9222/json/version > /dev/null 2>&1; }
no_crash() { ! grep -aq 'FATAL' "$1"; }
target() {  # target id of the page whose URL ends with ?$1
  curl -fsS http://127.0.0.1:9222/json/list | python3 -c \
    "import json,sys; print(next(t['id'] for t in json.load(sys.stdin) if t['url'].endswith('?$1')))"
}
eval_in() {  # eval_in <query> <js>
  $CDP Runtime.evaluate "{\"expression\":\"$2\",\"returnByValue\":true,\"userGesture\":true}" \
    --target "$(target "$1")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"].get("value"))'
}
window_of() {
  $CDP Browser.getWindowForTarget "{\"targetId\":\"$(target "$1")\"}" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["windowId"])'
}
window_state() {
  $CDP Browser.getWindowBounds "{\"windowId\":$1}" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["bounds"]["windowState"])'
}
quit_browser() {
  $CDP Browser.close > /dev/null 2>&1
  for _ in $(seq 1 20); do
    pgrep -f "$OUT/Chromium.app/Contents/MacOS/Chromium" > /dev/null || return 0
    sleep 1
  done
}

if pgrep -f "$OUT/Chromium.app/Contents/MacOS/Chromium" > /dev/null; then
  echo "Quit the test browser first."; exit 2
fi
mkdir -p "$SITE"
cat > "$SITE/index.html" << 'EOF'
<!doctype html><title>profile-tabs test</title><h1 id=h></h1><script>h.textContent='cookie: '+(document.cookie||'(none)')</script>
EOF
curl -fsS -o /dev/null http://127.0.0.1:8765/ 2> /dev/null ||
  (cd "$SITE" && nohup python3 -m http.server 8765 --bind 127.0.0.1 > server.log 2>&1 &)
sleep 1
echo "build: $OUT, profile dir: $USER_DATA_DIR"

python3 "$TOOLS/seed-profiles.py" --restore > /dev/null
LOG=$LOG1 URL_BASE=http://127.0.0.1:8765/ "$TOOLS/open-profiles.sh" > /dev/null

check "4 profile windows in one group" \
  "tabs_log $LOG1 | grep -q 'attached Delta, group size 4'"
check "native tab bar hidden, all-profiles tab strip shown in all 4" \
  "[ \$(tabs_log $LOG1 | grep -c 'strip shown') -eq 4 ] && ! tabs_log $LOG1 | grep -q 'native tab bar layout'"

eval_in Alpha "document.cookie='who=Alpha; max-age=600', 1" > /dev/null
check "cookies isolated (Bravo does not see Alpha's cookie)" \
  "[ \"\$(eval_in Bravo document.cookie)\" = '' ] && [ \"\$(eval_in Alpha document.cookie)\" = 'who=Alpha' ]"

before=$(tabs_log $LOG1 | grep -c attached)
eval_in Alpha "!!window.open('http://127.0.0.1:8765/?popup','pop','popup,width=420,height=320')" > /dev/null
"$TOOLS/run-test.sh" --profile-directory="Profile 1" --app="http://127.0.0.1:8765/?app" > /dev/null 2>&1
sleep 4
check "popup and app windows stay out of the group" \
  "[ \$(tabs_log $LOG1 | grep -c attached) -eq $before ]"

"$TOOLS/run-test.sh" --profile-directory="Profile 1" --incognito "http://127.0.0.1:8765/?incognito" > /dev/null 2>&1
sleep 4
"$TOOLS/run-test.sh" --profile-directory="Profile 2" --new-window "http://127.0.0.1:8765/?charlie2" > /dev/null 2>&1
sleep 4
check "incognito window joins as 'Bravo (Incognito)'" \
  "tabs_log $LOG1 | grep -q 'attached Bravo (Incognito)'"
check "second Charlie window joins as 'Charlie 2'" \
  "tabs_log $LOG1 | grep -q 'attached Charlie 2'"

# Fullscreen on the selected tab (the last window attached).
w=$(window_of charlie2)
for round in 1 2 3; do
  $CDP Browser.setWindowBounds "{\"windowId\":$w,\"bounds\":{\"windowState\":\"fullscreen\"}}" > /dev/null
  sleep 6
  in_state=$(alive && window_state "$w")
  $CDP Browser.setWindowBounds "{\"windowId\":$w,\"bounds\":{\"windowState\":\"normal\"}}" > /dev/null
  sleep 6
  check "fullscreen round $round (entered, exited, no crash)" \
    "alive && [ '$in_state' = fullscreen ] && [ \"\$(window_state $w)\" = normal ] && no_crash $LOG1"
done

# Shared fullscreen: switching profiles inside fullscreen keeps fullscreen.
$CDP Browser.setWindowBounds "{\"windowId\":$w,\"bounds\":{\"windowState\":\"fullscreen\"}}" > /dev/null
sleep 6
$CDP Target.activateTarget "{\"targetId\":\"$(target Alpha)\"}" > /dev/null
sleep 5
alpha_state=$(window_state "$(window_of Alpha)")
check "switching to Alpha inside fullscreen keeps it fullscreen ($alpha_state)" "[ '$alpha_state' = fullscreen ]"
$CDP Browser.setWindowBounds "{\"windowId\":$(window_of Alpha),\"bounds\":{\"windowState\":\"normal\"}}" > /dev/null
sleep 8
all=$(for q in Alpha Bravo Charlie Delta charlie2; do window_state "$(window_of $q)"; done | sort -u | tr '\n' ' ')
check "leaving fullscreen returns every profile window to normal ($all)" "[ '$all' = 'normal ' ] && alive && no_crash $LOG1"

for q in charlie2 incognito; do
  $CDP Target.closeTarget "{\"targetId\":\"$(target $q)\"}" > /dev/null
  sleep 3
done
check "closing two profile tabs keeps the browser alive" "alive && no_crash $LOG1"

quit_browser
nohup "$TOOLS/run-test.sh" > "$LOG2" 2>&1 &
for _ in $(seq 1 60); do alive && break; sleep 1; done
sleep 12
check "restart restores 4 profile windows into one group" \
  "[ \$(tabs_log $LOG2 | grep -c 'attached\|first window') -ge 4 ] && tabs_log $LOG2 | grep -q 'group size 4'"
states=$(for q in Alpha Bravo Charlie Delta; do window_state "$(window_of $q)"; done | sort -u | tr '\n' ' ')
check "restored windows are in normal state ($states)" "[ '$states' = 'normal ' ]"
quit_browser
check "no crashes in either run" "no_crash $LOG1 && no_crash $LOG2"

echo
echo "Manual checks left: clicking and middle-clicking tabs of other profiles,"
echo "dragging tabs across profiles, tab and + right-click menus (Move to profile,"
echo "New tab in ...), Cmd+1...9 / Ctrl+Tab / Cmd+Opt+arrows follow the strip,"
echo "Ctrl+1...9, real logins on one site, DevTools window, the strip in fullscreen."
[ "$failures" -eq 0 ] && echo "ALL AUTOMATED CHECKS PASSED" || echo "$failures CHECK(S) FAILED"
exit "$failures"
