#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Spotlite"
NOTARY_PROFILE="${SPOTLITE_NOTARY_PROFILE:-spotlite-notary}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
RELEASE_DIR="${SPOTLITE_RELEASE_DIR:-$BUILD_DIR/release}"

VERSION="${1:-${SPOTLITE_VERSION:-}}"
if [[ -z "$VERSION" ]]; then
    VERSION="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
    VERSION="${VERSION#v}"
fi

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 1.0" >&2
    exit 1
fi

IDENTITY="${SPOTLITE_DEVELOPER_ID_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(
        security find-identity -v -p codesigning \
            | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
            | head -n 1
    )"
fi

if [[ -z "$IDENTITY" ]]; then
    echo "No Developer ID Application signing identity found." >&2
    echo "Install a Developer ID Application certificate or set SPOTLITE_DEVELOPER_ID_IDENTITY." >&2
    exit 1
fi

mkdir -p "$RELEASE_DIR"

echo "Building $APP_NAME $VERSION"
SPOTLITE_VERSION="$VERSION" \
SPOTLITE_BUILD_NUMBER="${SPOTLITE_BUILD_NUMBER:-1}" \
SPOTLITE_CODESIGN_IDENTITY="-" \
    bash "$ROOT_DIR/scripts/build_app_bundle.sh"

echo "Signing with: $IDENTITY"
codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$IDENTITY" \
    "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

NOTARY_ZIP="$RELEASE_DIR/$APP_NAME-v$VERSION-notary.zip"
FINAL_ZIP="$RELEASE_DIR/$APP_NAME-v$VERSION-macos.zip"

rm -f "$NOTARY_ZIP" "$FINAL_ZIP"
ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ZIP"

echo "Submitting to Apple notary service with keychain profile: $NOTARY_PROFILE"
xcrun notarytool submit "$NOTARY_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP"

echo "Release ZIP: $FINAL_ZIP"
