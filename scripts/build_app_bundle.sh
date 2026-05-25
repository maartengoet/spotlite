#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Spotlite"
BUNDLE_ID="dev.maartengoet.spotlite"
APP_VERSION="${SPOTLITE_VERSION:-0.1.0}"
BUNDLE_VERSION="${SPOTLITE_BUILD_NUMBER:-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGN_IDENTITY="${SPOTLITE_CODESIGN_IDENTITY:-}"
LOCAL_SIGN_IDENTITY="Spotlite Local Development"

cd "$ROOT_DIR"

swift build \
    -c release \
    --product "$APP_NAME" \
    -Xcc "-fmodules-cache-path=.build/clang-module-cache" \
    -Xswiftc "-module-cache-path" \
    -Xswiftc ".build/swift-module-cache"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
swift scripts/generate_app_icon.swift "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -z "$SIGN_IDENTITY" ]]; then
    if security find-identity -v -p codesigning | grep -F "\"$LOCAL_SIGN_IDENTITY\"" >/dev/null; then
        SIGN_IDENTITY="$LOCAL_SIGN_IDENTITY"
    else
        SIGN_IDENTITY="-"
    fi
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Built $APP_DIR"
    echo "Signed ad-hoc. macOS privacy permissions may need to be re-granted after rebuilds."
else
    echo "Built $APP_DIR"
    echo "Signed with $SIGN_IDENTITY"
fi
