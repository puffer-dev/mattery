#!/bin/zsh
# Mattery release script.
# Builds Release, replaces /Applications/Mattery.app, and relaunches.

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
cd "$PROJECT_ROOT"

APP_NAME="Mattery"
INSTALL_PATH="/Applications/${APP_NAME}.app"
BUILD_DIR="$PROJECT_ROOT/build"
PRODUCT_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  clean build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify 2>/dev/null || \
  xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$PRODUCT_PATH" ]]; then
  echo "Build product not found at $PRODUCT_PATH" >&2
  exit 1
fi

echo "==> Quitting running instance (if any)"
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
# Also kill by name as a fallback (LSUIElement apps may not respond to AppleScript).
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 1

echo "==> Installing to ${INSTALL_PATH}"
rm -rf "$INSTALL_PATH"
cp -R "$PRODUCT_PATH" "$INSTALL_PATH"

# Re-sign ad-hoc so Gatekeeper accepts after the move.
codesign --force --deep --sign - "$INSTALL_PATH"

echo "==> Launching"
open "$INSTALL_PATH"

echo "==> Done: ${INSTALL_PATH}"
