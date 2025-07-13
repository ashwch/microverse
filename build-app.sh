#!/bin/bash

# Build the app
echo "Building Microverse..."
swift build -c release --product Microverse

# Create app bundle
APP_NAME="Microverse"
APP_BUNDLE="$APP_NAME.app"
EXECUTABLE_PATH=".build/arm64-apple-macosx/release/$APP_NAME"
CONTENTS_PATH="$APP_BUNDLE/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

# Remove old app bundle if exists
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy executable
cp "$EXECUTABLE_PATH" "$MACOS_PATH/$APP_NAME"


# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Microverse</string>
    <key>CFBundleIdentifier</key>
    <string>com.diversio.microverse</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Microverse</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSFaceIDUsageDescription</key>
    <string>Microverse needs authentication to control battery charging settings.</string>
</dict>
</plist>
EOF

# Copy to Applications
echo "Installing to /Applications..."
rm -rf "/Applications/$APP_BUNDLE"
cp -R "$APP_BUNDLE" "/Applications/"

echo "Done! Microverse has been installed to /Applications"
echo "Run: open /Applications/Microverse.app"