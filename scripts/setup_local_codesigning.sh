#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${SPOTLITE_CODESIGN_IDENTITY:-Spotlite Local Development}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/spotlite-codesign.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if security find-identity -v -p codesigning | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    echo "Code-signing identity already exists: $IDENTITY_NAME"
    exit 0
fi

CERT_PEM="$WORK_DIR/SpotliteLocalDevelopment.cer.pem"
KEY_PEM="$WORK_DIR/SpotliteLocalDevelopment.key.pem"
P12_FILE="$WORK_DIR/SpotliteLocalDevelopment.p12"
P12_PASSWORD="spotlite-local"

openssl req \
    -x509 \
    -newkey rsa:2048 \
    -sha256 \
    -days 3650 \
    -nodes \
    -keyout "$KEY_PEM" \
    -out "$CERT_PEM" \
    -subj "/CN=$IDENTITY_NAME/" \
    -addext "keyUsage=digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1

openssl pkcs12 \
    -export \
    -out "$P12_FILE" \
    -inkey "$KEY_PEM" \
    -in "$CERT_PEM" \
    -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

security import "$P12_FILE" \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$CERT_PEM" >/dev/null

security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "" \
    "$KEYCHAIN" >/dev/null 2>&1 || true

if security find-identity -v -p codesigning | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    echo "Created code-signing identity: $IDENTITY_NAME"
    echo "Rebuild with: bash scripts/build_app_bundle.sh"
else
    echo "Created certificate, but it is not listed as a valid code-signing identity." >&2
    echo "Open Keychain Access, trust '$IDENTITY_NAME' for Code Signing, then rerun this script." >&2
    exit 1
fi
