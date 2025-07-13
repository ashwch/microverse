#!/bin/bash

# Microverse Installer Build Script
# This script builds and packages the Microverse app for distribution

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$PROJECT_DIR/release"
APP_NAME="Microverse"
BUNDLE_ID="com.microverse.app"
VERSION="1.0.0"

echo "🚀 Building Microverse v$VERSION"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app
echo "🔨 Building Microverse app..."
cd "$PROJECT_DIR"
xcodebuild -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    build

# Find the built app
APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    exit 1
fi

echo "✅ App built at: $APP_PATH"

# Build the helper tool
echo "🔨 Building privileged helper..."
cd "$PROJECT_DIR/MicroverseHelper"
swift build -c release
HELPER_PATH="$PROJECT_DIR/MicroverseHelper/.build/release/MicroverseHelper"

# Create the installer package structure
echo "📦 Creating installer package..."
PKG_ROOT="$BUILD_DIR/pkg_root"
PKG_SCRIPTS="$BUILD_DIR/pkg_scripts"
mkdir -p "$PKG_ROOT/Applications"
mkdir -p "$PKG_ROOT/Library/PrivilegedHelperTools"
mkdir -p "$PKG_SCRIPTS"

# Copy app to package root
cp -R "$APP_PATH" "$PKG_ROOT/Applications/"

# Copy helper to package root
cp "$HELPER_PATH" "$PKG_ROOT/Library/PrivilegedHelperTools/com.microverse.helper"
chmod 755 "$PKG_ROOT/Library/PrivilegedHelperTools/com.microverse.helper"

# Create postinstall script
cat > "$PKG_SCRIPTS/postinstall" << 'EOF'
#!/bin/bash

# Install the helper tool
HELPER_PATH="/Library/PrivilegedHelperTools/com.microverse.helper"
PLIST_PATH="/Library/LaunchDaemons/com.microverse.helper.plist"

# Create the LaunchDaemon plist
cat > "$PLIST_PATH" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.microverse.helper</string>
    <key>MachServices</key>
    <dict>
        <key>com.microverse.helper</key>
        <true/>
    </dict>
    <key>Program</key>
    <string>/Library/PrivilegedHelperTools/com.microverse.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/com.microverse.helper</string>
    </array>
</dict>
</plist>
PLIST

# Set correct permissions
chown root:wheel "$HELPER_PATH"
chmod 755 "$HELPER_PATH"
chown root:wheel "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

# Load the helper
launchctl load "$PLIST_PATH"

exit 0
EOF

chmod 755 "$PKG_SCRIPTS/postinstall"

# Create preinstall script to unload old version if exists
cat > "$PKG_SCRIPTS/preinstall" << 'EOF'
#!/bin/bash

# Unload existing helper if present
if [ -f "/Library/LaunchDaemons/com.microverse.helper.plist" ]; then
    launchctl unload "/Library/LaunchDaemons/com.microverse.helper.plist" 2>/dev/null || true
fi

exit 0
EOF

chmod 755 "$PKG_SCRIPTS/preinstall"

# Build the installer package
echo "📦 Building installer package..."
pkgbuild --root "$PKG_ROOT" \
    --scripts "$PKG_SCRIPTS" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$BUILD_DIR/Microverse.pkg"

# Create a nice DMG with the app and installer
echo "💿 Creating DMG..."
DMG_NAME="Microverse-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

# Create DMG source folder
DMG_SOURCE="$BUILD_DIR/dmg_source"
mkdir -p "$DMG_SOURCE"
cp -R "$APP_PATH" "$DMG_SOURCE/"
cp "$BUILD_DIR/Microverse.pkg" "$DMG_SOURCE/Install Microverse.pkg"

# Create README for DMG
cat > "$DMG_SOURCE/README.txt" << 'EOF'
Microverse - Battery Management for macOS

Installation:
1. Run "Install Microverse.pkg" to install with privileged helper
   OR
2. Drag Microverse.app to Applications folder for basic installation

The installer package is recommended for full functionality including
automatic battery management features that require system access.

For more information, visit:
https://github.com/yourusername/microverse
EOF

# Create the DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_SOURCE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Create a ZIP alternative
echo "🗜 Creating ZIP archive..."
cd "$DMG_SOURCE"
zip -r "$RELEASE_DIR/Microverse-$VERSION.zip" .

echo "✨ Build complete!"
echo ""
echo "📦 Installer package: $BUILD_DIR/Microverse.pkg"
echo "💿 DMG: $DMG_PATH"
echo "🗜 ZIP: $RELEASE_DIR/Microverse-$VERSION.zip"
echo ""
echo "🔏 Note: For distribution, you'll need to:"
echo "   1. Code sign the app with your Developer ID"
echo "   2. Code sign the installer package"
echo "   3. Notarize both with Apple"
echo "   4. Staple the notarization ticket"