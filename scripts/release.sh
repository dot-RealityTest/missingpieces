#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="PiecesTask"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
TEAM_ID="${DEVELOPMENT_TEAM:-P5RB3W3D58}"
ENTITLEMENTS="$ROOT/PiecesTask/PiecesTask.entitlements"
RELEASE_DIR="$ROOT/release"
STAGING="$RELEASE_DIR/dmg-staging"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' PiecesTask/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' PiecesTask/Info.plist)"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}-b${BUILD}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (${BUILD}) Release…"
xcodebuild -project PiecesTask.xcodeproj -target PiecesTask -configuration Release \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  build

APP="$ROOT/build/Release/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "Release app not found at $APP" >&2
  exit 1
fi

echo "==> Verifying code signature…"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP" || true

echo "==> Creating DMG…"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/${APP_NAME}.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/release/INSTALL.txt" "$STAGING/Install PiecesTask.txt"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

echo "==> Done."
echo "App: $APP"
echo "DMG: $DMG_PATH"
echo
echo "Optional notarization (after storing credentials with notarytool):"
echo "  xcrun notarytool submit \"$DMG_PATH\" --keychain-profile YOUR_PROFILE --wait"
echo "  xcrun stapler staple \"$DMG_PATH\""
