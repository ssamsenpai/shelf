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
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG="build/Shelf-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Shelf" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
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
