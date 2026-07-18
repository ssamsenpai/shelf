#!/bin/bash
# Build Shelf and open it. Usage: ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "Building Shelf..."
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug build \
  -quiet 2>&1 | grep -E "error:|warning: unused" || true

APP="$(xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2}')/Shelf.app"

if [ ! -d "$APP" ]; then
  echo "Build failed, no app produced." >&2
  exit 1
fi

# Keep a stable alias in the repo so you never need the DerivedData path.
rm -f ./Shelf.app
ln -s "$APP" ./Shelf.app

pkill -x Shelf 2>/dev/null || true
open "$APP"
echo "Launched: $APP"
