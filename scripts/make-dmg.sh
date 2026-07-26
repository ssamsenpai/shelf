#!/bin/bash
# Builds Shelf and packages it as a DMG.
#
# Unsigned by default. Set these to sign and notarize:
#   SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)"
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD   app-specific password
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Release \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ MARKETING_VERSION/{print $2; exit}')
echo "==> Building Shelf $VERSION"

xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Release \
  -derivedDataPath build/DerivedData build | grep -E "error|warning: unused|BUILD" || true

APP="build/DerivedData/Build/Products/Release/Shelf.app"
[ -d "$APP" ] || { echo "Build produced no app" >&2; exit 1; }

if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "==> Signing with Developer ID"
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP"
else
  echo "==> No SIGN_IDENTITY, shipping the ad hoc signed build"
fi

echo "==> Creating DMG"
STAGE="build/dmg-stage"
rm -rf "$STAGE" && mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
cp packaging/dmg-background.png "$STAGE/.background/background.png"
ln -s /Applications "$STAGE/Applications"

DMG="build/Shelf-$VERSION.dmg"
RW="build/Shelf-rw.dmg"
rm -f "$DMG" "$RW"

# Build read-write first so Finder can lay the window out, then compress.
hdiutil detach "/Volumes/Shelf" >/dev/null 2>&1 || true
hdiutil create -volname "Shelf" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null

# Window: no chrome, branded background, big icons either side of the arrow.
osascript <<'OSA' >/dev/null || echo "==> Finder styling skipped (automation permission?)"
tell application "Finder"
  tell disk "Shelf"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 1060, 628}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "Shelf.app" of container window to {165, 220}
    set position of item "Applications" of container window to {495, 220}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

sync
hdiutil detach "/Volumes/Shelf" >/dev/null
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -f "$RW"
echo "==> $DMG"

if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "==> Notarizing"
  xcrun notarytool submit "$DMG" --wait \
    --apple-id "$NOTARY_APPLE_ID" \
    --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD"
  xcrun stapler staple "$DMG"
  echo "==> Notarized and stapled"
else
  echo "==> Skipping notarization, users will need right click, Open"
fi

hdiutil verify "$DMG" >/dev/null && echo "==> DMG verified"
