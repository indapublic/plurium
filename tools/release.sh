#!/bin/bash
# Signs and notarizes out/Release and packages it as
# Plurium-<version>-arm64.dmg. With --publish it also uploads the DMG as a
# GitHub release and bumps Casks/plurium.rb (commit + push).
#
# One-time setup:
#   - "Developer ID Application" certificate in the login keychain;
#   - notarization credentials saved under a keychain profile:
#       xcrun notarytool store-credentials plurium --apple-id <apple id> \
#         --team-id 4WSCP7LMZQ
#
# Usage: tools/release.sh [--publish]
#   REVISION=N  release number for the same Chromium version (default 1)
#   IDENTITY, NOTARY_PROFILE, GH_REPO, ROOT override the defaults below.
set -euo pipefail

ROOT=${ROOT:-/Volumes/Workspace/chromium}
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/src/out/Release
IDENTITY=${IDENTITY:-"Developer ID Application: Vasilii Zolotukhin (4WSCP7LMZQ)"}
NOTARY_PROFILE=${NOTARY_PROFILE:-plurium}
GH_REPO=${GH_REPO:-indapublic/plurium}
REVISION=${REVISION:-1}
PUBLISH=0
[ "${1:-}" = "--publish" ] && PUBLISH=1

step() { echo; echo "=== $*"; }

# Apple's timestamp server occasionally does not answer.
retry() {
  local attempt
  for attempt in 1 2 3; do
    "$@" && return 0
    echo "Attempt $attempt failed: $*"
    sleep 20
  done
  return 1
}

# Submits $1 to Apple's notary service, waits, fails with the log unless
# accepted.
notarize() {
  local result status id
  result=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format json)
  echo "$result"
  status=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))' <<< "$result")
  if [ "$status" != Accepted ]; then
    id=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("id"))' <<< "$result")
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" || true
    echo "Notarization of $1: $status"
    exit 1
  fi
}

CHROMIUM_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$OUT/Chromium.app/Contents/Info.plist")
VERSION=$CHROMIUM_VERSION-$REVISION
WORK=$OUT/plurium-release
DMG=$WORK/Plurium-$VERSION-arm64.dmg

step "Plurium $VERSION (Chromium $CHROMIUM_VERSION)"
[ -x "$OUT/Chromium Packaging/sign_chrome.py" ] ||
  { echo "Build the signing scripts first: autoninja -C out/Release chrome chrome/installer/mac"; exit 1; }
security find-identity -v -p codesigning | grep -qF "$IDENTITY" ||
  { echo "Signing identity not found: $IDENTITY"; exit 1; }
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null ||
  { echo "No notarization credentials in keychain profile '$NOTARY_PROFILE' (see the header)"; exit 1; }

rm -rf "$WORK"
mkdir -p "$WORK"

step "Sign the app (Chromium's own signing scripts)"
# Chromium's pipeline keeps a notarized app only inside its own packaging, so
# it just signs here and the notarization follows below.
python3 "$REPO_DIR/tools/sign.py" "$OUT/Chromium Packaging" --input "$OUT" \
  --output "$WORK/signed" --identity "$IDENTITY" --disable-packaging
APP=$(find "$WORK/signed" -maxdepth 3 -name Chromium.app -type d | head -1)
[ -n "$APP" ] || { echo "Signed Chromium.app not found in $WORK/signed"; exit 1; }
codesign --verify --deep --strict "$APP"

step "Notarize the app"
ditto -c -k --keepParent "$APP" "$WORK/app.zip"
notarize "$WORK/app.zip"
xcrun stapler staple "$APP"
spctl --assess --type execute -vv "$APP"

step "DMG"
mkdir -p "$WORK/dmg"
ditto "$APP" "$WORK/dmg/Plurium.app"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -volname "Plurium" -srcfolder "$WORK/dmg" -fs APFS -format ULFO -ov "$DMG"
retry codesign --force --sign "$IDENTITY" --timestamp "$DMG"

step "Notarize the DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"
SHA256=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
echo "$DMG"
echo "sha256 $SHA256"

if [ "$PUBLISH" -eq 0 ]; then
  echo
  echo "Not published. Run again with --publish to create release v$VERSION."
  exit 0
fi

step "Publish v$VERSION to $GH_REPO"
gh release create "v$VERSION" "$DMG" --repo "$GH_REPO" --title "Plurium $VERSION" \
  --notes "Plurium $VERSION, based on Chromium $CHROMIUM_VERSION (macOS, Apple Silicon).

Install or update: \`brew upgrade --cask plurium\` (see README)."
CASK=$REPO_DIR/Casks/plurium.rb
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" "$CASK"
git -C "$REPO_DIR" add Casks/plurium.rb
git -C "$REPO_DIR" commit -m "Plurium $VERSION"
git -C "$REPO_DIR" push
echo "Published. Users update with: brew update && brew upgrade --cask plurium"
