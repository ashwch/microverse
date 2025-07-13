#!/bin/bash

# Code signing and notarization script for Microverse
# Requires valid Apple Developer ID certificates

set -e

# Configuration
DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
BUNDLE_ID="com.microverse.app"
APPLE_ID="your-apple-id@example.com"
TEAM_ID="TEAMID"
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" # App-specific password

APP_PATH="$1"
PKG_PATH="$2"

if [ -z "$APP_PATH" ] || [ -z "$PKG_PATH" ]; then
    echo "Usage: $0 <app-path> <pkg-path>"
    exit 1
fi

echo "🔏 Code signing Microverse..."

# Sign the helper tool first
echo "Signing helper tool..."
codesign --force --options runtime \
    --sign "$DEVELOPER_ID_APP" \
    --timestamp \
    "$APP_PATH/Contents/Library/LaunchServices/com.microverse.helper"

# Sign frameworks
echo "Signing frameworks..."
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -exec \
    codesign --force --options runtime \
    --sign "$DEVELOPER_ID_APP" \
    --timestamp {} \;

# Sign the app bundle
echo "Signing app bundle..."
codesign --force --options runtime \
    --sign "$DEVELOPER_ID_APP" \
    --timestamp \
    --entitlements "$PROJECT_DIR/Microverse.entitlements" \
    "$APP_PATH"

# Verify the signature
echo "Verifying app signature..."
codesign --verify --deep --verbose=2 "$APP_PATH"
spctl -a -t exec -vvv "$APP_PATH"

# Sign the installer package
echo "Signing installer package..."
productsign --sign "$DEVELOPER_ID_INSTALLER" \
    "$PKG_PATH" \
    "${PKG_PATH%.pkg}-signed.pkg"

mv "${PKG_PATH%.pkg}-signed.pkg" "$PKG_PATH"

# Create a ZIP for notarization
echo "Creating ZIP for notarization..."
ZIP_PATH="${APP_PATH%.app}.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Submit for notarization
echo "Submitting app for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# Submit package for notarization
echo "Submitting package for notarization..."
xcrun notarytool submit "$PKG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# Staple the notarization ticket
echo "Stapling notarization ticket to app..."
xcrun stapler staple "$APP_PATH"

echo "Stapling notarization ticket to package..."
xcrun stapler staple "$PKG_PATH"

# Verify notarization
echo "Verifying notarization..."
spctl -a -t exec -vvv "$APP_PATH"
spctl -a -t install -vvv "$PKG_PATH"

echo "✅ Code signing and notarization complete!"