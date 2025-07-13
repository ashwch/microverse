#!/bin/bash

echo "🚀 Quick building Microverse..."

# Create app bundle structure
APP_NAME="Microverse"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Clean and create directories
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Compile Swift files directly
echo "🔨 Compiling Swift files..."
swiftc \
    -o "$MACOS/$APP_NAME" \
    -framework SwiftUI \
    -framework AppKit \
    -framework IOKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    -target arm64-apple-macos11.0 \
    Sources/Microverse/*.swift \
    Sources/BatteryCore/*.swift \
    Sources/SMCKit/*.swift

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

# Create Info.plist
cp Info.plist "$CONTENTS/"

# Create basic icon
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>" > "$RESOURCES/AppIcon.icns"

# Make executable
chmod +x "$MACOS/$APP_NAME"

echo "✅ Build complete!"
echo "📍 App location: $APP_BUNDLE"
echo ""
echo "Run with: open $APP_BUNDLE"